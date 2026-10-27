import Foundation
import Metal

func runMetalWorkload(seconds:Double) throws {
    guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else {throw NSError(domain:"MemoriaFixture",code:1,userInfo:[NSLocalizedDescriptionKey:"Metal unavailable"])}
    let source="""
    #include <metal_stdlib>
    using namespace metal;
    kernel void exercise(device float *out [[buffer(0)]], uint index [[thread_position_in_grid]]) {
        float x = float(index) * 0.001f;
        for (uint i=0; i<512; ++i) { x = sin(x + float(i)*0.0001f) * 1.001f + cos(x); }
        out[index] = x;
    }
    """
    let library=try device.makeLibrary(source:source,options:nil)
    guard let function=library.makeFunction(name:"exercise") else {throw NSError(domain:"MemoriaFixture",code:2)}
    let pipeline=try device.makeComputePipelineState(function:function)
    let count=262144
    guard let buffer=device.makeBuffer(length:count*MemoryLayout<Float>.stride,options:.storageModeShared) else {throw NSError(domain:"MemoriaFixture",code:3)}
    let deadline=ProcessInfo.processInfo.systemUptime+min(120,max(1,seconds))
    while ProcessInfo.processInfo.systemUptime < deadline {
        guard let command=queue.makeCommandBuffer(),let encoder=command.makeComputeCommandEncoder() else {throw NSError(domain:"MemoriaFixture",code:4)}
        encoder.setComputePipelineState(pipeline);encoder.setBuffer(buffer,offset:0,index:0)
        encoder.dispatchThreads(MTLSize(width:count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:min(256,pipeline.maxTotalThreadsPerThreadgroup),height:1,depth:1))
        encoder.endEncoding();command.commit();command.waitUntilCompleted()
        if let error=command.error {throw error}
    }
}
