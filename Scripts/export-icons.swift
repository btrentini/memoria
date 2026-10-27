// Deterministic format/size exports of the checked-in image-generation masters.
// No network, private APIs or running application are needed.
import Foundation
import CoreGraphics
import ImageIO
import CoreText
import SwiftUI

enum ExportError:Error {case image(String),context,output(String)}
let root=URL(fileURLWithPath:CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath,isDirectory:true)
let brand=root.appendingPathComponent("Branding",isDirectory:true)
let output=brand.appendingPathComponent("Exports",isDirectory:true)
let srgb=CGColorSpace(name:CGColorSpace.sRGB)!
let gray=CGColorSpace(name:CGColorSpace.genericGrayGamma2_2)!
func folder(_ url:URL) throws {try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)}
func read(_ name:String) throws -> CGImage {
    let url=brand.appendingPathComponent("Source/"+name)
    guard let source=CGImageSourceCreateWithURL(url as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,nil) else {throw ExportError.image(name)}
    return image
}
func context(_ width:Int,_ height:Int) throws -> CGContext {
    guard let ctx=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:srgb,
        bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue|CGBitmapInfo.byteOrder32Big.rawValue) else {throw ExportError.context}
    ctx.interpolationQuality = .high;ctx.setShouldAntialias(true)
    return ctx
}
func png(_ image:CGImage,_ file:URL,dpi:Double=72) throws {
    try folder(file.deletingLastPathComponent())
    guard let destination=CGImageDestinationCreateWithURL(file as CFURL,"public.png" as CFString,1,nil) else {throw ExportError.output(file.path)}
    CGImageDestinationAddImage(destination,image,[kCGImagePropertyDPIWidth:dpi,kCGImagePropertyDPIHeight:dpi] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {throw ExportError.output(file.path)}
}
func resized(_ image:CGImage,_ size:Int) throws -> CGImage {
    let ctx=try context(size,size);ctx.draw(image,in:CGRect(x:0,y:0,width:size,height:size));return ctx.makeImage()!
}
func greyscale(_ image:CGImage) throws -> CGImage {
    guard let ctx=CGContext(data:nil,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width,space:gray,bitmapInfo:CGImageAlphaInfo.none.rawValue) else {throw ExportError.context}
    ctx.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height));return ctx.makeImage()!
}
// Conventional .icns stores a flattened enclosure. The modern .icon source is
// unmasked, and receives the exact platform mask/effects from Apple's renderer.
func legacy(_ image:CGImage,_ size:Int) throws -> CGImage {
    let ctx=try context(size,size)
    let inset=Double(size)/16,rect=CGRect(x:inset,y:inset,width:Double(size)-2*inset,height:Double(size)-2*inset)
    let path=RoundedRectangle(cornerRadius:rect.width*0.225,style:.continuous).path(in:rect).cgPath
    ctx.addPath(path);ctx.clip();ctx.draw(image,in:rect);return ctx.makeImage()!
}
let mark=try resized(read("Brain-Cobalt-Original.png"),1024)
let light=try resized(read("Icon-Default-Original.png"),1024)
let dark=try resized(read("Icon-Dark-Original.png"),1024)
let mono=try greyscale(light)
try png(mark,brand.appendingPathComponent("Memoria.icon/Assets/Brain.png"))
try png(mark,output.appendingPathComponent("Logo-Cobalt-1024.png"))

// Locate the visible glyph for a dedicated menu-bar export. Do not shrink the
// app icon's padded enclosure into the status item. Colours come from the OS.
let menu=try resized(read("Brain-Menu-Original.png"),1024)
let analysis=try context(menu.width,menu.height)
analysis.draw(menu,in:CGRect(x:0,y:0,width:menu.width,height:menu.height))
let bytes=analysis.data!.assumingMemoryBound(to:UInt8.self)
var minX=menu.width,minY=menu.height,maxX=0,maxY=0
for y in 0..<menu.height {for x in 0..<menu.width where bytes[(y*menu.width+x)*4+3]>=128 {
    minX=min(minX,x);minY=min(minY,y);maxX=max(maxX,x);maxY=max(maxY,y)
}}
guard maxX>minX,maxY>minY else {throw ExportError.image("Empty foreground")}
let bounds=CGRect(x:minX,y:menu.height-maxY-1,width:maxX-minX+1,height:maxY-minY+1)
func template(_ size:Int) throws -> CGImage {
    let ctx=try context(size,size)
    let available=Double(size)*8/9,scale=min(available/bounds.width,available/bounds.height)
    let x=(Double(size)-bounds.width*scale)/2-bounds.minX*scale
    let y=(Double(size)-bounds.height*scale)/2-bounds.minY*scale
    ctx.draw(menu,in:CGRect(x:x,y:y,width:Double(menu.width)*scale,height:Double(menu.height)*scale))
    ctx.setBlendMode(.sourceIn);ctx.setFillColor(CGColor(gray:0,alpha:1));ctx.fill(CGRect(x:0,y:0,width:size,height:size))
    return ctx.makeImage()!
}
for (size,name) in [(16,"BrainTemplate16.png"),(32,"BrainTemplate16@2x.png"),(18,"BrainTemplate.png"),(36,"BrainTemplate@2x.png"),(24,"BrainTemplate24.png"),(48,"BrainTemplate24@2x.png"),(32,"BrainMark.png"),(64,"BrainMark@2x.png")] {
    let image=try template(size)
    let dpi=Double(name.contains("@2x") ? 144:72)
    try png(image,root.appendingPathComponent("App/Resources/"+name),dpi:dpi)
    try png(image,output.appendingPathComponent("MenuBar/"+name),dpi:dpi)
}

var manifest:[[String:Any]]=[]
let variants:[(String,CGImage)]=[("Default",light),("Dark",dark),("Mono",mono)]
for (name,master) in variants {
    try png(master,output.appendingPathComponent(name+"-1024-Unmasked.png"))
    for size in [16,32,64,128,256,512,1024] {
        let file=output.appendingPathComponent("PNG/"+name+"/Memoria-\(size).png")
        try png(legacy(master,size),file)
        manifest.append(["path":file.path.replacingOccurrences(of:root.path+"/",with:""),"pixels":size,"appearance":name,"role":"Flattened fallback; not Icon Composer input"])
    }
    let iconset=output.appendingPathComponent("Memoria-"+name+".iconset",isDirectory:true)
    try folder(iconset)
    let iconFile=output.appendingPathComponent("Memoria-"+name+".icns")
    guard let container=CGImageDestinationCreateWithURL(iconFile as CFURL,"com.apple.icns" as CFString,10,nil) else {throw ExportError.output(iconFile.path)}
    for points in [16,32,128,256,512] {for scale in [1,2] {
        let suffix=scale==2 ? "@2x":""
        let image=try legacy(master,points*scale)
        try png(image,iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"),dpi:Double(72*scale))
        CGImageDestinationAddImage(container,image,[kCGImagePropertyDPIWidth:72*scale,kCGImagePropertyDPIHeight:72*scale] as CFDictionary)
    }}
    guard CGImageDestinationFinalize(container),let decoded=CGImageSourceCreateWithURL(iconFile as CFURL,nil),CGImageSourceGetCount(decoded)==10 else {throw ExportError.output("ICNS encoding: "+name)}
    var decodedSizes=Set<String>()
    for index in 0..<10 {
        guard let image=CGImageSourceCreateImageAtIndex(decoded,index,nil),let properties=CGImageSourceCopyPropertiesAtIndex(decoded,index,nil) as? [String:Any],
              let dpi=properties[kCGImagePropertyDPIWidth as String] as? Double else {throw ExportError.output("ICNS decoding: "+name)}
        let scale=Int((dpi/72).rounded()),points=image.width/scale
        guard [16,32,128,256,512].contains(points),[1,2].contains(scale),image.height==image.width else {throw ExportError.output("ICNS dimensions: "+name)}
        decodedSizes.insert("\(points)@\(scale)")
    }
    guard decodedSizes.count==10 else {throw ExportError.output("ICNS Retina representations: "+name)}
    print("\(name): ImageIO encoded and decoded all ten 1x/2x ICNS representations.")
}

// Proof sheet: artwork and native-pixel small sizes. This is a review artefact,
// not a screenshot of Finder, the Dock, or Icon Composer.
let sheet=try context(1440,1080)
sheet.setFillColor(CGColor(red:0.953,green:0.965,blue:0.984,alpha:1));sheet.fill(CGRect(x:0,y:0,width:1440,height:1080))
@MainActor func text(_ string:String,_ x:Double,_ y:Double,_ size:Double=18,_ color:CGColor=CGColor(gray:0.16,alpha:1)) {
    let font=CTFontCreateWithName("HelveticaNeue" as CFString,size,nil)
    let attributes:[NSAttributedString.Key:Any]=[NSAttributedString.Key(kCTFontAttributeName as String):font,NSAttributedString.Key(kCTForegroundColorAttributeName as String):color]
    let line=CTLineCreateWithAttributedString(NSAttributedString(string:string,attributes:attributes))
    sheet.textPosition=CGPoint(x:x,y:y);CTLineDraw(line,sheet)
}
text("Memoria",64,1000,44)
text("A calm, recognisable brain mark for a native Mac monitor.",66,963,19,CGColor(gray:0.40,alpha:1))
for (index,item) in variants.enumerated() {
    let x=64+Double(index)*456
    sheet.setFillColor(index==1 ? CGColor(red:0.055,green:0.075,blue:0.13,alpha:1):CGColor(gray:1,alpha:1))
    sheet.fill(CGRect(x:x,y:507,width:400,height:400))
    sheet.draw(try legacy(item.1,380),in:CGRect(x:x+10,y:517,width:380,height:380))
    text(item.0 == "Default" ? "Default / light":item.0 == "Dark" ? "Dark":"Monochrome",x,475,22)
    text(item.0 == "Mono" ? "Grayscale export":"1024 px master",x,447,15,CGColor(gray:0.45,alpha:1))
    sheet.setFillColor(index==1 ? CGColor(red:0.055,green:0.075,blue:0.13,alpha:1):CGColor(gray:1,alpha:1))
    sheet.fill(CGRect(x:x,y:225,width:400,height:184))
    var cursor=x+16
    for size in [16,32,64,128] as [Int] {
        sheet.draw(try legacy(item.1,size),in:CGRect(x:cursor,y:254,width:Double(size),height:Double(size)))
        text("\(size)",cursor,236,11,index==1 ? CGColor(gray:0.8,alpha:1):CGColor(gray:0.4,alpha:1))
        cursor += Double(size)+26
    }
}
text("Small sizes above are shown at 1:1 pixels.",64,192,15,CGColor(gray:0.4,alpha:1))
text("Menu bar",64,131,18)
for (x,isDark) in [(180.0,false),(390.0,true)] {
    sheet.setFillColor(isDark ? CGColor(gray:0.13,alpha:1):CGColor(gray:1,alpha:1));sheet.fill(CGRect(x:x,y:111,width:170,height:44))
    let glyph=try template(36),r=CGRect(x:x+18,y:124,width:18,height:18)
    sheet.saveGState();sheet.clip(to:r,mask:glyph);sheet.setFillColor(CGColor(gray:isDark ? 1:0.1,alpha:1));sheet.fill(r);sheet.restoreGState()
    text("CPU 12%",x+50,127,14,CGColor(gray:isDark ? 0.9:0.18,alpha:1))
}
text("Artwork proof · native Icon Composer rendering still requires environment verification.",64,54,14,CGColor(gray:0.45,alpha:1))
try png(sheet.makeImage()!,brand.appendingPathComponent("Preview.png"))
let data=try JSONSerialization.data(withJSONObject:["schema":1,"exports":manifest,"menuBarPoints":18,"templatePoints":[16,18,24,32],"menuBarScales":[1,2],"nativeSource":"Branding/Memoria.icon","nativeRenderingVerified":false],options:[.prettyPrinted,.sortedKeys])
try data.write(to:output.appendingPathComponent("Manifest.json"),options:.atomic)
print("Exported default, dark and monochrome PNG/iconset/icns assets, 16/18/24/32pt templates and Branding/Preview.png.")
