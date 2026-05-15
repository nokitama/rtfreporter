rtf_commands <- list(
  document = list(
    rtf_header_open = "{\\rtf1\\ansi\\deff0",
    font_table_template = "{\\fonttbl{\\f0 {font_name};}}",
    color_table_default = "{\\colortbl;\\red0\\green0\\blue0;}",
    page_settings_template = "\\paperw{width_twips}\\paperh{height_twips}\\landscape\\margl{margin_left_twips}\\margr{margin_right_twips}\\margt{margin_top_twips}\\margb{margin_bottom_twips}\\fs{font_size_half_points}",
    section_defaults = "\\sectd",
    page_break = "\\page",
    section_break = "\\sect",
    header_wrapper = "{\\header {content}}",
    footer_wrapper = "{\\footer {content}}",
    document_close = "}"
  ),
  paragraph = list(
    center_bold_template = "\\pard\\qc\\b {text}\\b0\\par",
    left_template = "\\pard\\ql {text}\\par",
    figure_placeholder_center_template = "\\pard\\qc [Figure: {filename}]\\par",
    empty_table = "\\par [empty table]\\par"
  ),
  table = list(
    row_start = "\\trowd",
    row_end = "\\row",
    row_height_template = "\\trrh{row_height_twips}",
    # Legacy cell templates used by .render_header_footer().
    cell_boundary_template = "\\cellx{cx}",
    cell_boundary_top_border_template = "\\clbrdrt\\brdrs\\brdrw10\\cellx{cx}",
    header_cell_text_template = "\\b {text}\\b0\\cell",
    cell_text_template = "{text}\\cell",
    cell_text_aligned_template = "{align} {text}\\cell"
  ),
  alignment = list(
    left    = "\\ql",
    right   = "\\qr",
    center  = "\\qc",
    default = "\\ql"
  ),
  # RTF cell-border side prefixes and style codes.
  border = list(
    side_prefix = list(
      top    = "\\clbrdrt",
      bottom = "\\clbrdrb",
      left   = "\\clbrdrl",
      right  = "\\clbrdrr"
    ),
    style = list(
      single = "\\brdrs",
      double = "\\brdrdb",
      thick  = "\\brdrth",
      dash   = "\\brdrdash",
      dot    = "\\brdrdot"
    )
  ),
  # Cell vertical alignment commands.
  cell_valign = list(
    top    = "\\clvertalt",
    center = "\\clvertalc",
    bottom = "\\clvertalb"
  ),
  # Inline text decoration on/off pairs.
  text_decor = list(
    bold      = list(on = "\\b ",      off = "\\b0 "),
    italic    = list(on = "\\i ",      off = "\\i0 "),
    underline = list(on = "\\ul ",     off = "\\ulnone "),
    super     = list(on = "\\super ",  off = "\\nosupersub "),
    sub       = list(on = "\\sub ",    off = "\\nosupersub ")
  ),
  # RTF picture templates for PNG and JPEG embedding.
  picture = list(
    png_template  = "\\pard{align}{\\pict\\pngblip\\picw{picw}\\pich{pich}\\picwgoal{picwgoal}\\pichgoal{pichgoal}\n{hex}\n}\\par",
    jpeg_template = "\\pard{align}{\\pict\\jpegblip\\picw{picw}\\pich{pich}\\picwgoal{picwgoal}\\pichgoal{pichgoal}\n{hex}\n}\\par"
  )
)
