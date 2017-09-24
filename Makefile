.PHONY: clean clean-images check-branch release

EMACS := emacsclient

main-results.pdf : main-results.org
	$(EMACS) --eval "(progn (find-file \"./main-results.org\") (org-latex-export-to-pdf))"

clean :
	rm -rf main-resuts.tex main-results.pdf

clean-images :
	rm -rf ltximg/*

release : check-branch main-results.pdf
	./release
	git add ./README.md
	git commit -m 'New PDF release'
	git push origin master:master

check-branch :
	@if [ $$(git rev-parse --abbrev-ref HEAD) != "master" ]; then echo "Not in master branch: aborting"; false; fi
