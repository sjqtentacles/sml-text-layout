(* demo.sml - wrap a paragraph into a fixed-width box and render it to a PNG via
   the vendored sml-font, plus dump the resolved line/glyph geometry as text.
   Deterministic and byte-identical across MLton and Poly/ML. *)

structure TL = TextLayout

fun readFile path =
  let val ins = TextIO.openIn path val s = TextIO.inputAll ins
  in TextIO.closeIn ins; s end

val font = Font.parseBdf (readFile "data/font5x7.bdf")

val text =
  "PURE STANDARD ML TEXT LAYOUT - GREEDY WORD WRAP AND UNICODE AWARE \
  \MEASUREMENT ON TOP OF SML FONT AND SML UNICODE. BYTE IDENTICAL ON \
  \MLTON AND POLYML."

val scale   = 2
val cell    = TL.cellWidth font            (* 6 px *)
val maxCols = 28                            (* wrap column count *)
val maxW    = maxCols * cell                (* wrap width in scale-1 px *)
val lh      = Font.height font + 2          (* line height with a little leading *)

val layout = TL.wrap { font = font, maxWidth = maxW, lineHeight = SOME lh } text

(* image is the wrapped box scaled up, with an 8px margin *)
val margin = 8
val imgW = (maxW + margin * 2) * scale
val imgH = (#height layout + margin * 2) * scale

val bg : Image.rgba8    = { r = 0w15,  g = 0w23,  b = 0w42,  a = 0w255 }  (* slate *)
val fg : Image.rgba8    = { r = 0w226, g = 0w232, b = 0w240, a = 0w255 }  (* light *)

val blank = Image.fill (imgW, imgH) bg

(* draw each glyph cluster at its resolved position, scaled *)
val img =
  List.foldl
    (fn ({ glyphs, ... } : TL.line, acc) =>
       List.foldl
         (fn ({ ch, x, y, ... } : TL.glyphpos, im) =>
            Font.drawText im
              { x = (x + margin) * scale, y = (y + margin) * scale
              , scale = scale, color = fg } font ch)
         acc glyphs)
    blank (#lines layout)

val () =
  let val os = BinIO.openOut "assets/wrapped.png"
  in BinIO.output (os, Image.encodePng img); BinIO.closeOut os end

(* text geometry dump *)
fun lineStr ({ y, width, glyphs } : TL.line) =
  "  y=" ^ Int.toString y ^ " width=" ^ Int.toString width ^
  " glyphs=" ^ Int.toString (length glyphs)
val dump =
  "wrap maxWidth=" ^ Int.toString maxW ^ " lineHeight=" ^ Int.toString lh ^ "\n" ^
  "layout " ^ Int.toString (#width layout) ^ "x" ^ Int.toString (#height layout) ^
  ", " ^ Int.toString (length (#lines layout)) ^ " lines:\n" ^
  String.concatWith "\n" (map lineStr (#lines layout)) ^ "\n"

val () =
  let val os = TextIO.openOut "assets/wrapped.txt"
  in TextIO.output (os, dump); TextIO.closeOut os end

val () = print ("sml-text-layout demo: wrote assets/wrapped.png ("
                ^ Int.toString (Word8Vector.length (Image.encodePng img))
                ^ " bytes, " ^ Int.toString imgW ^ "x" ^ Int.toString imgH
                ^ ") and assets/wrapped.txt\n")
val () = print dump
