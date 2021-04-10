;; Guile pty module
;;
;; Copyright (c) 2021 liujia6264@gmail.com 
;;
;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
;; THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
;; THE SOFTWARE.

(define-module (pty)
  #:use-module (system foreign)
  #:use-module (rnrs bytevectors)
  #:use-module (srfi srfi-11)
  #:use-module (ice-9 expect)
  #:export (open-pty-process))

(eval-when (expand load eval)
  (load-extension (string-append "libguile-" (effective-version))
                  "scm_init_popen"))

(define openpty
  (let ((this (dynamic-link "libutil")))
    (pointer->procedure int
			(dynamic-func "openpty" this)
			(list '* '* '* '* '*))))
(define fork 
  (let ((this (dynamic-link)))
    (pointer->procedure int
			(dynamic-func "fork" this)
			(list))))

(define ioctl
  (let ((this (dynamic-link)))
    (pointer->procedure int
			(dynamic-func "ioctl" this)
			(list int unsigned-long '*))))

(define setsid
  (let ((this (dynamic-link)))
    (pointer->procedure int
			(dynamic-func "setsid" this)
			(list))))

(define setgid
  (let ((this (dynamic-link)))
    (pointer->procedure int
			(dynamic-func "setgid" this)
			(list int))))

(define setuid
  (let ((this (dynamic-link)))
    (pointer->procedure int
			(dynamic-func "setuid" this)
			(list int))))

(define getgid
  (let ((this (dynamic-link)))
    (pointer->procedure int
			(dynamic-func "getgid" this)
			(list))))

(define getuid
  (let ((this (dynamic-link)))
    (pointer->procedure int
			(dynamic-func "getuid" this)
			(list))))

(define open-pty
  (lambda ()
    (let* ((ptm (make-bytevector 4))
	   (pts (make-bytevector 4))
	   (pmaster (bytevector->pointer ptm))
	   (pslave (bytevector->pointer pts)))
      (let ((ret (openpty pmaster pslave %null-pointer %null-pointer %null-pointer)))
	   (if (= ret -1)
	     (cons -1 -1)
	     (let ((master (bytevector-s32-native-ref ptm 0))
		   (slave (bytevector-s32-native-ref pts 0)))
	       (cons master slave)))))))

(define setctltty
  (lambda (fd)
    (let ((req #X540E))
      (ioctl fd req %null-pointer))))

(define strerror
  (let ((this (dynamic-link)))
    (pointer->procedure '*
			(dynamic-func "strerror" this)
			(list int))))

(define perrno (dynamic-pointer "errno" (dynamic-link)))

(define c-error
  (lambda ()
    (let ([errno (bytevector-s32-native-ref (pointer->bytevector perrno (sizeof int)) 0)])
      (pointer->string (strerror errno)))))

(define check
  (lambda (who x)
    (if (< x 0)
        (error who (c-error))
        x)))

(define dofork
  (lambda (child parent)
    (let ([pid (fork)])
      (cond
        [(= pid 0) (child)]
        [(> pid 0) (parent pid)]
        [else (error 'fork "fork")]))))

(define open-pty-process
  (lambda (command)
    (let* ([pair (open-pty)]
	   [master (car pair)] [slave (cdr pair)])
      (dofork
	(lambda ()
	  (close master)
	  (setsid)
	  (setctltty slave)
	  (setgid (getgid))
	  (setuid (getuid))
    	  (dup2 slave 0)
    	  (dup2 slave 1)
    	  (dup2 slave 2)
    	  (close slave)
          (execl "/bin/sh" "/bin/sh" "-c" command)
          (error 'open-pty-process "subprocess exec failed"))
	(lambda (pid)
	  (close slave)
	  (let ((port (fdopen master "rw")))
	    (set-port-revealed! port 1)
	    (close master)
	    (setvbuf port 'none)
	    (values port pid)))))))
