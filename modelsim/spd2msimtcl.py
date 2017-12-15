
#
# Generate Modelsim compile script for *.qsys system
# using information from *.spd file (created by qsys-generate)
#

import argparse
import os

ABOUT = "Generate Modelsim compile script for *.qsys system from *.spd file \
(created by qsys-generate)"


def parse_spd(spdfile):
    import xml.etree.ElementTree as et

    ver_files = []
    sv_pkg_files = []
    vhdl_files = []
    vhdl_pkg_files = []
    dev_family = ""

    tree = et.ElementTree(file=spdfile)
    if tree.getroot().tag != "simPackage":
        raise Exception("XML file is not valid SPD file!")

    for node in tree.getroot():
        if node.tag == "file":
            if node.attrib["type"] == "SYSTEM_VERILOG":
                if node.attrib["path"].endswith("_pkg.sv"):
                    sv_pkg_files.append(node.attrib["path"])
                else:
                    ver_files.append(node.attrib["path"])
            elif node.attrib["type"] == "VERILOG":
                ver_files.append(node.attrib["path"])
            elif node.attrib["type"] == "VHDL":
                if node.attrib["path"].endswith("_pkg.vhd"):
                    vhdl_pkg_files.append(node.attrib["path"])
                else:
                    vhdl_files.append(node.attrib["path"])
        elif node.tag == "deviceFamily":
            dev_family = node.attrib["name"]

    return ver_files, sv_pkg_files, vhdl_files, vhdl_pkg_files


vlib_tmpl = """
proc ensure_lib {{ lib }} {{ if ![file isdirectory $lib] {{ vlib $lib }} }}
ensure_lib ./libraries/
ensure_lib ./libraries/{libname}/
vmap {libname} ./libraries/{libname}/"""

ver_tmpl = """
vlog -sv -work {libname} {files}"""

vhd_tmpl = """
vcom -work {libname} {files}"""


def gen_msim_tcl(worklib, ver_files, sv_pkg_files, vhdl_files, vhdl_pkg_files, outdir):

    s = vlib_tmpl.format(libname=worklib) + "\n"

    for f in sv_pkg_files:
        s += ver_tmpl.format(libname=worklib,
                             files=outdir + "/" + f)
    for f in ver_files:
        s += ver_tmpl.format(libname=worklib,
                             files=outdir + "/" + f)
    for f in vhdl_pkg_files:
        s += vhd_tmpl.format(libname=worklib,
                             files=outdir + "/" + f)
    for f in vhdl_files:
        s += vhd_tmpl.format(libname=worklib,
                             files=outdir + "/" + f)

    s += "\nq\n"

    return s


def main():
    optparser = argparse.ArgumentParser(description=ABOUT)
    optparser.add_argument('-spd', action='store',
                           help='Input .spd file', required=True)
    optparser.add_argument('-tcl', action='store',
                           help='Output .tcl file', required=True)
    optparser.add_argument('-od', action='store',
                           help='qsys-generate output dir', required=True)

    args = optparser.parse_args()

    ver_files, sv_pkg_files, vhdl_files, vhdl_pkg_files = parse_spd(args.spd)
    libname = os.path.basename(args.spd).split(".")[0]

    tcl_code = gen_msim_tcl(libname,
                            ver_files, sv_pkg_files, vhdl_files, vhdl_pkg_files,
                            args.od)

    with open(args.tcl, "w") as f:
        f.write(tcl_code)


if __name__ == "__main__":
    main()
