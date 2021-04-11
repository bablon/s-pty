(add-to-load-path ".")

(use-modules (ice-9 expect))
(use-modules (pty))
(use-modules (srfi srfi-11))

(let-values ([(port pid) (open-pty-process "scheme")])
    (let ((expect-port port)
          (expect-timeout 1)
          (expect-timeout-proc
            (lambda (s) (display "Times up!\n") (close-port port)))
          (expect-eof-proc
            (lambda (s) (display "Reached the end of the file!\n")))
          (expect-char-proc display )
          (expect-strings-compile-flags (logior regexp/newline regexp/icase))
          (expect-strings-exec-flags 0))
       (expect-strings
         ("> "
	  (display "(machine-type)\n" port)))
       (expect-strings
         ("> "
	  (display "(exit)\n" port)))
       (expect-strings
         ("\\)"
	  (close-port port) (newline)))))
