import re
content = open(r"c:\Yrepo\rtfreporter\tests\quickstart_examples.R", encoding="utf-8").read()

# Fix token
content = content.replace("{PAGE}", "{AUTO_PAGE}")

# Remove set_default_header/footer for dm_report and combine into add_section
old1 = (
    "dm_report\$set_default_header(make_common_header(\"Table 14.1.1 Demographics\"))\n"
    "dm_report\$set_default_footer(make_common_footer())\n\n"
    "dm_sec <- dm_report\$add_section(\n"
    "  header = c(l = \"Demographics (Screened Population)\", r = \"Safety Set\")\n"
    ")"
)
new1 = (
    "dm_sec <- dm_report\$add_section(\n"
    "  header = list(rows = c(\n"
    "    make_common_header(\"Table 14.1.1 Demographics\")\$rows,\n"
    "    list(c(l = \"Demographics (Screened Population)\", r = \"Safety Set\"))\n"
    "  )),\n"
    "  footer = make_common_footer()\n"
    ")"
)
print("found dm block:", old1 in content)
content = content.replace(old1, new1)

# Remove set_default_header/footer for lb_report
old2 = (
    "lb_report\$set_default_header(make_common_header(\"Table 14.2.1 Clinical Laboratory Summary\"))\n"
    "lb_report\$set_default_footer(make_common_footer())"
)
new2 = ""
print("found lb block:", old2 in content)
content = content.replace(old2, new2)

open(r"c:\Yrepo\rtfreporter\tests\quickstart_examples.R", "w", encoding="utf-8").write(content)
print("done")

