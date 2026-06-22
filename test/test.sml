(* Tests for sml-text-layout: exact integer measurement and greedy word-wrap
   vectors against the vendored font5x7 BDF (monospace: cell advance 6, height
   7), plus Unicode-aware grapheme width (CJK = 2 cells, combining = 0). *)

structure Tests =
struct
  open Harness
  structure TL = TextLayout

  fun readFile path =
    let val ins = TextIO.openIn path val s = TextIO.inputAll ins
    in TextIO.closeIn ins; s end

  val font = Font.parseBdf (readFile "data/font5x7.bdf")

  (* render a layout's glyphs to a compact "ch@x,y(w)" list for golden asserts *)
  fun glyphStr ({ ch, x, y, w } : TL.glyphpos) =
    ch ^ "@" ^ Int.toString x ^ "," ^ Int.toString y ^ "(" ^ Int.toString w ^ ")"
  fun lineStr ({ y, width, glyphs } : TL.line) =
    "y=" ^ Int.toString y ^ " w=" ^ Int.toString width ^ " [" ^
    String.concatWith " " (map glyphStr glyphs) ^ "]"
  fun layoutStr ({ width, height, lines } : TL.layout) =
    "W=" ^ Int.toString width ^ " H=" ^ Int.toString height ^ "\n" ^
    String.concatWith "\n" (map lineStr lines)

  fun wrap mw s = TL.wrap { font = font, maxWidth = mw, lineHeight = NONE } s

  (* UTF-8 fixtures *)
  val cjk  = "\228\184\173"      (* U+4E2D 中 (wide, 2 cells) *)
  val comb = "a\204\129"         (* a + U+0301 combining acute (1 cluster) *)

  fun runAll () =
    let
      (* ---- cell / grapheme width ---- *)
      val () = section "width"
      val () = checkInt "cellWidth = 6" (6, TL.cellWidth font)
      val () = checkInt "grapheme A width" (6, TL.graphemeWidth font "A")
      val () = checkInt "grapheme CJK width" (12, TL.graphemeWidth font cjk)
      val () = checkInt "grapheme combining width" (6, TL.graphemeWidth font comb)

      (* ---- measure ---- *)
      val () = section "measure"
      val () = checkEq "empty measures (0,0)" ((0, 0), TL.measure font "")
      val () = checkEq "HELLO measures (30,7)" ((30, 7), TL.measure font "HELLO")
      val () = checkEq "AB CD measures (30,7)" ((30, 7), TL.measure font "AB CD")
      val () = checkEq "two lines measures (18,14)" ((18, 14), TL.measure font "AB\nCDE")
      val () = checkEq "cjk measures (12,7)" ((12, 7), TL.measure font cjk)

      (* ---- wrap: empty ---- *)
      val () = section "wrap empty"
      val () = checkInt "empty -> zero lines" (0, length (#lines (wrap 100 "")))
      val () = checkString "empty layout"
                 ("W=0 H=0\n", layoutStr (wrap 100 ""))

      (* ---- wrap: single line under width ---- *)
      val () = section "wrap single line"
      val () = checkString "HELLO one line, width = sum of advances"
                 ("W=30 H=7\ny=0 w=30 [H@0,0(6) E@6,0(6) L@12,0(6) L@18,0(6) O@24,0(6)]",
                  layoutStr (wrap 100 "HELLO"))

      (* ---- wrap: split at the expected space ---- *)
      val () = section "wrap at space"
      (* "AB CD EF": "AB CD" (w=30) fits in 30; " EF" overflows -> new line *)
      val () = checkString "AB CD EF wraps after CD"
                 ("W=30 H=14\n" ^
                  "y=0 w=30 [A@0,0(6) B@6,0(6) " ^ " @12,0(6) C@18,0(6) D@24,0(6)]\n" ^
                  "y=7 w=12 [E@0,7(6) F@6,7(6)]",
                  layoutStr (wrap 30 "AB CD EF"))

      (* ---- wrap: force-break an over-long word ---- *)
      val () = section "wrap force-break"
      (* "ABCDEF" in maxWidth 20: ABC (18) | DEF (18) *)
      val () = checkString "long word force-broken"
                 ("W=18 H=14\n" ^
                  "y=0 w=18 [A@0,0(6) B@6,0(6) C@12,0(6)]\n" ^
                  "y=7 w=18 [D@0,7(6) E@6,7(6) F@12,7(6)]",
                  layoutStr (wrap 20 "ABCDEF"))

      (* ---- wrap: hard newline forces a break and resets x ---- *)
      val () = section "wrap newline"
      val () = checkString "newline forces new line"
                 ("W=12 H=14\n" ^
                  "y=0 w=12 [A@0,0(6) B@6,0(6)]\n" ^
                  "y=7 w=12 [C@0,7(6) D@6,7(6)]",
                  layoutStr (wrap 100 "AB\nCD"))

      (* ---- wrap: blank line preserved ---- *)
      val () = section "wrap blank line"
      val () = checkInt "AB\\n\\nCD -> 3 lines" (3, length (#lines (wrap 100 "AB\n\nCD")))

      (* ---- wrap: leading space dropped on continuation ---- *)
      val () = section "wrap leading space"
      (* CJK then CJK: each 12 wide, maxWidth 12 -> two lines *)
      val () = checkString "two wide chars wrap"
                 ("W=12 H=14\n" ^
                  "y=0 w=12 [" ^ cjk ^ "@0,0(12)]\n" ^
                  "y=7 w=12 [" ^ cjk ^ "@0,7(12)]",
                  layoutStr (wrap 12 (cjk ^ cjk)))

      (* ---- custom line height ---- *)
      val () = section "line height"
      val lay = TL.wrap { font = font, maxWidth = 100, lineHeight = SOME 10 } "AB\nCD"
      val () = checkInt "custom lineHeight applied to height" (20, #height lay)
      val () = checkInt "second line y = 10"
                 (10, #y (hd (tl (#lines lay))))
    in () end

  fun run () = (reset (); runAll (); Harness.run ())
end
