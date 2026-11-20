import AppKit
@main enum BilingualLayoutTests {
 static func main() {
  let small = NSRect(x: 0,y: 0,width: 78,height: 240)
  precondition(BilingualLayout.translation(nil, enabled: true) == nil)
  precondition(BilingualLayout.translation("中文", enabled: false) == nil)
  precondition(BilingualLayout.translation(" \n ", enabled: true) == nil)
  precondition(BilingualLayout.translation(" 中文 ", enabled: true) == "中文")
  for vertical in [false,true] {
   let original = vertical ? small.insetBy(dx: 8,dy: 8) : NSRect(x:16,y:6,width:280,height:40)
   let pair = BilingualLayout.regions(original: original, lineHeight: 20, bilingual: true, vertical: vertical)
   precondition(pair.original.minY >= pair.translation.maxY)
   precondition(pair.original.width >= 0 && pair.original.height >= 0)
   precondition(pair.translation.width == original.width)
   let single = BilingualLayout.regions(original: original,lineHeight:20,bilingual:false,vertical:vertical)
   precondition(single.original == original && single.translation == .zero)
  }
  print("PASS bilingual enabled/empty/missing and horizontal/vertical layout boundaries")
 }
}
