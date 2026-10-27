use macmon::{Sampler, sources::IOReport};
use serde_json::{Value, json};
use std::collections::BTreeSet;
use std::io::{self, Read, Write};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const VERSION: u32 = 1;
const MAX_LINE: usize = 65_536;

fn emit(message: Value) -> io::Result<()> {
    let line = serde_json::to_vec(&message)?;
    if line.len() > MAX_LINE { return Err(io::Error::other("message size limit")); }
    let mut output = io::stdout().lock();
    output.write_all(&line)?;
    output.write_all(b"\n")?;
    output.flush()
}

fn valid(value: f64, low: f64, high: f64) -> bool {
    value.is_finite() && value >= low && value <= high
}

fn metric(id: &str, value: Option<f64>, unit: &str, api: &str, time: f64, interval: f64) -> Value {
    let date = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs_f64() - 978_307_200.0;
    json!({
        "id": id, "value": value.map(|v| json!({"number":{"_0":v}})),
        "unit": unit, "wallTime": date, "monotonicTime": time, "interval": interval,
        "provider": "macmon 39e98aa (isolated)", "api": api, "tier": 2,
        "permission": "unknown", "availability": if value.is_some() {"available"} else {"unavailable"},
        "quality": "Experimental; channel presence and range checked. Independent hardware validation pending.",
        "measurement": if unit == "watts" || unit == "ratio" {"intervalDelta"} else {"gauge"},
        "error": if value.is_none() {Some("Counter absent, unsupported or outside validated range")} else {None}
    })
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // A dedicated process group lets the supervising application also stop a profiler fallback child.
    unsafe { libc::setpgid(0, 0); }
    let started = Instant::now();
    emit(json!({"version":VERSION,"type":"hello","sequence":0,"monotonic":0.0,"capabilities":[]}))?;
    let parent = unsafe { libc::getppid() };
    std::thread::spawn(move || loop {
        std::thread::sleep(Duration::from_millis(500));
        if unsafe { libc::getppid() } != parent {
            unsafe { libc::kill(-libc::getpid(), libc::SIGTERM); libc::_exit(0); }
        }
    });
    // EOF on the owned control pipe is cancellation, including graceful application shutdown.
    std::thread::spawn(|| {
        let mut byte = [0u8; 1];
        loop {
            match io::stdin().read(&mut byte) {
                Ok(0) | Err(_) => unsafe { libc::kill(-libc::getpid(), libc::SIGTERM); libc::_exit(0); },
                Ok(_) => {}
            }
        }
    });
    let mut sequence = 1u64;
    let mut sampler = match Sampler::new() {
        Ok(s) => s,
        Err(error) => {
            emit(json!({"version":VERSION,"type":"error","sequence":sequence,"monotonic":started.elapsed().as_secs_f64(),"error":format!("Sampler unavailable: {error}")}))?;
            return Ok(());
        }
    };
    let soc = sampler.get_soc_info().clone();
    // Unknown combinations fail closed for IOReport interpretation. Temperature/fan Options remain explicit.
    let mut version_buf = [0u8; 256];
    let mut len = version_buf.len();
    let os_ok = unsafe {
        libc::sysctlbyname(c"kern.osproductversion".as_ptr(), version_buf.as_mut_ptr().cast(), &mut len, std::ptr::null_mut(), 0)
    } == 0;
    let os = String::from_utf8_lossy(&version_buf[..len.min(version_buf.len())]);
    let supported = os_ok && os.starts_with("26.") && soc.chip_name == "Apple M2 Pro" && !soc.vm;
    let discovery = IOReport::new(vec![("Energy Model", None), ("GPU Stats", Some("GPU Performance States"))]).ok();
    let mut previous = started.elapsed().as_secs_f64();
    loop {
        let readings = sampler.get_metrics(1000)?;
        let time = started.elapsed().as_secs_f64();
        let interval = time - previous;
        previous = time;
        let mut channels = BTreeSet::new();
        if supported && let Some(ref report) = discovery {
            for channel in report.get_sample(1) {
                if channel.group == "Energy Model" && ["mJ","uJ","nJ"].contains(&channel.unit.as_str()) {
                    if channel.channel.ends_with("CPU Energy") { channels.insert("cpu.power"); }
                    if channel.channel == "GPU Energy" { channels.insert("gpu.power"); }
                    if channel.channel.starts_with("ANE") { channels.insert("ane.power"); }
                    if channel.channel.starts_with("DRAM") { channels.insert("dram.power"); }
                }
                if channel.group == "GPU Stats" && channel.channel == "GPUPH" && soc.gpu_freqs.len() > 1 {
                    let residency = macmon::sources::cfio_get_residencies(channel.item);
                    if !residency.is_empty() && residency.iter().all(|(_, ticks)| *ticks >= 0) && residency.iter().map(|(_,ticks)| *ticks as i128).sum::<i128>() > 0 {
                        channels.insert("gpu.active"); channels.insert("gpu.scaled"); channels.insert("gpu.frequency");
                    }
                }
            }
        }
        let mut samples = Vec::new();
        for (id, value, unit, low, high) in [
            ("cpu.power", readings.cpu_power as f64, "watts", 0.0, 300.0),
            ("gpu.power", readings.gpu_power as f64, "watts", 0.0, 300.0),
            ("ane.power", readings.ane_power as f64, "watts", 0.0, 100.0),
            ("dram.power", readings.ram_power as f64, "watts", 0.0, 100.0),
            ("gpu.active", readings.gpu_active_ratio as f64, "ratio", 0.0, 1.0),
            ("gpu.scaled", readings.gpu_scaled_ratio as f64, "ratio", 0.0, 1.0),
            ("gpu.frequency", readings.gpu_freq_mhz as f64, "megahertz", 0.0, 5000.0),
        ] {
            samples.push(metric(id, (channels.contains(id) && valid(value,low,high)).then_some(value),unit,"IOReport",time,interval));
        }
        for (id, value) in [("cpu.temperature",readings.temp.cpu_temp_avg),("gpu.temperature",readings.temp.gpu_temp_avg)] {
            let value = value.map(f64::from).filter(|v| valid(*v,0.0,150.0));
            if value.is_some() { channels.insert(id); }
            samples.push(metric(id,value,"celsius","SMC / IOHID",time,interval));
        }
        let mut capability_ids: Vec<String> = channels.iter().map(|s|s.to_string()).collect();
        for (i, fan) in readings.fans.iter().take(16).enumerate() {
            let id = format!("fan.{i}.rpm");
            let value = fan.rpm as f64;
            let value = valid(value,0.0,20000.0).then_some(value);
            if value.is_some() { capability_ids.push(id.clone()); }
            samples.push(metric(&id,value,"rpm","SMC",time,interval));
        }
        emit(json!({"version":VERSION,"type":"capabilities","sequence":sequence,"monotonic":time,"capabilities":capability_ids}))?;
        sequence += 1;
        emit(json!({"version":VERSION,"type":"sample","sequence":sequence,"monotonic":time,"samples":samples}))?;
        sequence += 1;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn range_validation_rejects_invalid_readings() {
        assert!(!valid(f64::NAN,0.0,100.0));
        assert!(!valid(f64::INFINITY,0.0,100.0));
        assert!(!valid(-1.0,0.0,100.0));
        assert!(valid(0.0,0.0,100.0));
    }
    #[test] fn absent_counter_is_null() {
        let value = metric("ane.power",None,"watts","IOReport",1.0,1.0);
        assert!(value["value"].is_null());
        assert_eq!(value["availability"],"unavailable");
    }
}
