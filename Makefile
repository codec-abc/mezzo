.PHONY: all clean test graph doc index release report coverage count doc doc-export install uninstall

# If the file doesn't exist, there's a rule for generating it.
-include Makefile.config

# Autodetected values for auxiliary tools can be overridden by Makefile.local
# (not under version control).
-include Makefile.local

# We have either the code of the type-checker, or the code of the run-time
# support library.
ML_DIRS    := lib parsing typing utils interpreter compiler tests/unit ocamlbuild
MZ_DIRS    := mezzolib corelib stdlib

# The executables that we need to build Mezzo.
OCAMLBUILD := ocamlbuild -j 4 -use-ocamlfind -use-menhir \
	      -menhir "menhir --explain --infer -la 1 --table" \
	      -classic-display \
	      $(addprefix -I ,$(ML_DIRS)) \
	      $(addprefix -I ,$(MZ_DIRS))
OCAMLFIND  := ocamlfind

# We're building two programs: the mezzo compiler and the test suite.
MAIN       := mezzo
TESTSUITE  := testsuite
# We're also building libraries for the run-time support of Mezzo prorams.
LIBS  	   := mezzolib/MezzoLib.cma mezzolib/MezzoLib.cmxa \
	      corelib/MezzoCoreLib.cma corelib/MezzoCoreLib.cmxa \
	      stdlib/MezzoStdLib.cma stdlib/MezzoStdLib.cmxa \
	      ocamlbuild/ocamlbuild_mezzo.cma ocamlbuild/ocamlbuild_mezzo.cmxa
# These are our targets.
TARGETS	   := $(MAIN).native $(TESTSUITE).native $(LIBS)

all: configure.ml parsing/Keywords.ml vim/syntax/mezzo.vim myocamlbuild.ml
	# This re-generates the list of modules that go into MezzoStdLib
	$(MAKE) -C stdlib/
	# This is the big call that builds everything.
	$(OCAMLBUILD) $(TARGETS)
	# For convenience, two symbolic links.
	ln -sf $(MAIN).native $(MAIN)
	ln -sf $(TESTSUITE).native $(TESTSUITE)

configure.ml Makefile.config: configure
	# If the user hasn't run ./configure already, we're assuming a local
	# setup where Mezzo isn't meant to be installed.
	./configure --local

parsing/Keywords.ml: parsing/Keywords parsing/KeywordGenerator.ml
	ocaml parsing/KeywordGenerator.ml < $< > $@
	if [ -d ../misc/pygments/mezzolexer ] ; then \
	  ocaml parsing/KeywordPygments.ml < $< > ../misc/pygments/mezzolexer/mezzokeywords.py ; \
	fi

vim/syntax/mezzo.vim: parsing/Keywords parsing/KeywordGenerator.ml
	ocaml parsing/KeywordGenerator.ml -vim $@.raw < $< > $@

myocamlbuild.ml: ocamlbuild/ocamlbuild_mezzo.ml myocamlbuild.pre.ml
	$(shell echo "(* This file is auto-generated by the Makefile *)\n" > $@)
	$(shell echo "module Ocamlbuild_mezzo = struct\n" >> $@)
	$(shell cat ocamlbuild/ocamlbuild_mezzo.ml >> $@)
	$(shell echo "end;;\n" >> $@)
	$(shell cat myocamlbuild.pre.ml >> $@)
	@echo "myocamlbuild.ml generated"

clean:
	rm -f *~ $(MAIN) $(MAIN).native $(TESTSUITE) $(TESTSUITE).native configure.ml Makefile.config \
	  myocamlbuild.ml
	$(OCAMLBUILD) -clean

test: all
	OCAMLRUNPARAM=b $(TIME) --format="Elapsed time (wall-clock): %E" ./testsuite

install: all
	$(OCAMLFIND) install mezzo META \
	  $(patsubst %,_build/%,$(LIBS)) \
	  $(shell $(FIND) _build/ocamlbuild/ \
	  	-iname '*.a' -or -iname '*.cmi' -or -iname '*.cmx') \
	  $(shell $(FIND) _build/corelib/ \
	  	-iname '*.a' -or -iname '*.cmi' -or -iname '*.cmx') \
	  $(shell $(FIND) _build/stdlib/ \
	  	-iname '*.a' -or -iname '*.cmi' -or -iname '*.cmx') \
	  $(shell $(FIND) _build/mezzolib/ \
	  	-iname '*.a' -or -iname '*.cmi' -or -iname '*.cmx') \
	  $(shell $(FIND) _build/corelib/ -iname '*.mzi') \
	  $(shell $(FIND) _build/stdlib/ -iname '*.mzi') \
	  corelib/autoload

uninstall:
	$(OCAMLFIND) remove mezzo


################################################################################

### Less-important build rules, mostly for the ease of us developers.

BUILDDIRS   = -I _build $(shell $(FIND) _build -maxdepth 1 -type d -printf "-I _build/%f ")
PACKAGES   := -package menhirLib,ocamlbuild,yojson,ulex,pprint,fix

# Re-generate the TAGS file
tags: all
	otags $(shell $(FIND) $(ML_DIRS) \( -iname '*.ml' -or -iname '*.mli' \) -and -not -iname 'Lexer.ml')

# When you need to build a small program linking with all the libraries (to
# write a test for a very specific function, for instance).
%.byte: FORCE
	$(OCAMLBUILD) $(INCLUDE) $*.byte

# For easily debugging inside an editor. When editing tests/foo.mz, just do (in
# vim): ":make %".
#%.mz: mezzo.byte FORCE
#	OCAMLRUNPARAM=b ./mezzo.byte -I tests -nofancypants $@ -debug 5 2>&1 | tail -n 80
%.mz: all
	OCAMLRUNPARAM=b ./mezzo.native -I tests $@ 2>&1 | tail -n 200

FORCE:

# For printing the signature of an .ml file
%.mli: all
	$(OCAMLFIND) ocamlc $(PACKAGES) -i $(BUILDDIRS) $*.ml

# The index of all the nifty visualizations we've built so far
index:
	$(shell cd viewer && ./gen_index.sh)

# TAG=m1 make release ; this just exports the current src/ directory
release:
	git archive --format tar --prefix mezzo-$(TAG)/ $(TAG) | bzip2 -9 > ../mezzo-$(TAG).tar.bz2

report:
	bisect-report -I _build -html report coverage*.out

coverage:
	BISECT_FILE=coverage ./testsuite

graph: all
	-$(OCAMLFIND) ocamldoc -dot $(BUILDDIRS)\
	  $(PACKAGES)\
	  -o graph.dot\
	  $(shell $(FIND) typing/ -iname '*.ml' -or -iname '*.mli')\
	  configure.ml mezzo.ml
	sed -i 's/rotate=90;//g' graph.dot
	dot -Tsvg graph.dot > misc/graph.svg
	sed -i 's/^<text\([^>]\+\)>\([^<]\+\)/<text\1><a xlink:href="\2.html" target="_parent">\2<\/a>/' misc/graph.svg
	sed -i 's/Times Roman,serif/DejaVu Sans, Helvetica, sans/g' misc/graph.svg
	rm -f graph.dot

doc: graph
	-$(OCAMLFIND) ocamldoc $(PACKAGES) \
	  $(BUILDDIRS) \
	  -stars -html \
	  -d ../misc/doc \
	  -intro ../misc/doc/main \
	  -charset utf8 -css-style ocamlstyle.css\
	  configure.ml mezzo.ml\
	  $(shell $(FIND) _build -maxdepth 2 -iname '*.mli')
	sed -i 's/<\/body>/<p align="center"><object type="image\/svg+xml" data="graph.svg"><\/object><\/p><\/body>/' ../misc/doc/index.html
	cp -f misc/graph.svg ../misc/doc/graph.svg

doc-export:
	rm -rf ~/public_html/mezzo-lang/doc/
	cp -R ../misc/doc ~/public_html/mezzo-lang/

count:
	sloccount parsing typing utils viewer lib mezzo.ml

