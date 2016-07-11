(defpackage "VECTOR-REAL"
  (:nicknames "RV")
  (:use "COMMON-LISP-USER")
  (:use "ALEXANDRIA"))

(in-package "VECTOR-REAL")

(declaim (inline ->dim))
(defun ->dim (u)
  (declare (type (vector long-float) u))
  (length u))

(declaim (inline ->[]))
(defun ->[] (u ix)
  (declare (type (vector long-float) u))
  (aref u ix))

(declaim (inline ->[]))
(defun (setf ->[]) (val u ix )
  (declare (type (vector long-float) u))
  (setf (aref u ix) (coerce val 'long-float)))

(declaim (inline ->make))
(defun ->make (n)
  (make-array n :element-type 'long-float))

(declaim (inline ->zero))
(defun ->zero (n)
  (make-array n :element-type 'long-float :initial-element 0.0d0))

(declaim (inline ->cube))
(defun ->cube (magnitude)
  (make-array n :element-type 'long-float :initial-element (coerce magnitude 'long-float)))

(declaim (inline ->clone))
(defun ->clone (v)
  (declare (type (vector long-float) v))
  (make-array (->dim v) :element-type 'long-float :initial-contents v))

(declaim (inline ->axis))
(defun ->axis (n ix &optional (magnitude 1.0d0))
  (let ((v (->zero n)))
    (setf (->[] v ix) (coerce magnitude 'long-float))
    v))

(declaim (inline ->))
(defun -> (&rest args)
  (let* ((n (length args))
         (v (->make n)))
    (do ((args args (cdr args))
         (i 0 (1+ i)))
        ((null args) v)
      (setf (->[] v i) (car args)))))

(declaim (inline ->set!))
(defun ->set! (u v)
  (declare (type (vexoctor long-float) u)
           (type (vector long-float) v))
  (dotimes (i (->dim u) u)
    (setf (->[] u i) (->[] v i))))

(defmacro defvop (op)
  (let ((->1op (intern (format nil "->1~s" op)))
        (->1op! (intern (format nil "->1~s!" op)))
        (->2op (intern (format nil "->2~s" op)))
        (->2op! (intern (format nil "->2~s!" op)))
        (->op (intern (format nil "->~s" op)))
        (->op! (intern (format nil "->~s!" op))))
    `(progn
       (declaim (inline ,->2op)
                (inline ,->2op!)
                (inline ,->1op)
                (inline ,->1op!))
       (values
        (defun ,->1op (u)
          (declare (type (vector long-float) u))
          (let* ((n (length u))
                (w (->make n)))
            (declare (type (vector long-float) w))
            (dotimes (i n w)
              (setf (->[] w i) (,op (->[] u i))))))

        (defun ,->1op! (u)
          (declare (type (vector long-float) u))
          (let ((n (length u)))
            (dotimes (i n u)
              (setf (->[] u i) (,op (->[] u i))))))

        (defun ,->2op (u v)
          (declare (type (vector long-float) u)
                   (type (vector long-float) v))
          (let* ((n (length u))
                 (w (->make n)))
            (declare (type (vector long-float) w))
            (dotimes (i n w)
              (setf (->[] w i) (,op (->[] u i) (->[] v i))))))

        (defun ,->2op! (u v)
          (declare (type (vector long-float) u)
                   (type (vector long-float) v))
          (let ((n (length u)))
            (dotimes (i n u)
              (setf (->[] u i) (,op (->[] u i) (->[] v i))))))

        (defmacro ,->op (u &rest vs)
          (if vs
              (with-gensyms (w)
                `(let ((,w (,',->2op ,u ,(car vs))))
                   ,@(mapcar #'(lambda (v) `(,',->2op! ,w ,v)) (cdr vs))))
              `(,',->1op ,u)))
        
        (defmacro ,->op! (u &rest vs)
          (if vs
              (once-only (u)
                `(progn
                   ,@(mapcar #'(lambda (v) `(,',->2op! ,u ,v)) vs)))
              `(,',->1op! ,u)))))))
         
(defvop +)
(defvop -)

(declaim (inline ->scale))
(defun ->scale (u r)
  (declare (type (vector long-float) u))
  (let* ((r (coerce r 'long-float))
         (n (->dim u))
         (w (->make n)))
    (dotimes (i n w)
      (setf (->[] w i) (* (->[] u i) r)))))

(declaim (inline ->scale!))
(defun ->scale! (u r)
  (declare (type (vector long-float) u))
  (let* ((r (coerce r 'long-float)))
    (dotimes (i (->dim u) w)
      (setf (->[] u i) (* (->[] u i) r)))))

(declaim (inline ->*))
(defun ->* (a b)
  (typecase a
    ((vector long-float) (->scale a b))
    ((t (->scale b a)))))

(declaim (inline ->.))
(defun ->. (u v)
  (declare (type (vector long-float) u)
           (type (vector long-float) v))
  (let ((acu 0)
        (n (->dim u)))
    (dotimes (i n acu)
      (incf acu (* (->[] u i) (->[] v i))))))

(declaim (inline ->/))
(defun ->/ (u r)
  (declare (type (vector long-float) u))
  (let* ((inv-r (/ 1.0d0 (coerce c 'long-float)))
         (n (->dim u))
         (w (->make n)))
    (dotimes (i n w)
      (setf (->[] w i) (* (->[] u i) inv-r)))))

(declaim (inline ->/!))
(defun ->/! (u r)
  (declare (type (vector long-float) u))
  (let* ((inv-r (/ 1.0d0 (coerce c 'long-float))))
    (dotimes (i (->dim u) u)
      (setf (->[] u i) (* (->[] u i) inv-r)))))

(declaim (inline ->*+!))
(defun ->2*+! (u v s)
  (declare (type (vector long-float) u)
           (type (vector long-float) v))
  (let ((s (coerce s 'long-float)))
    (dotimes (i (->dim u) u)
      (incf (->[] u i) (* (->[] v i) s)))))

(declaim (inline ->2*+))
(defun ->2*+ (u r v s)
  (declare (type (vector long-float) u)
           (type (vector long-float) v))
  (let* ((r (coerce r 'long-float))
         (s (coerce s 'long-float))
         (n (->dim u))
         (w (->make n)))
    (dotimes (i n w)
      (setf (->[] w i) (+ (* (->[] u i) r) (* (->[] v i) s))))))

(defun ->*+!-aux (u vs-ss)
  (if vs-ss
      `( (->2*+! ,u ,(car vs-ss) ,(cadr vs-ss))
         ,@(->*+!-aux u (cddr vs-ss)))
      `(,u)))

(defmacro ->*+! (u &rest vs-ss)
  (once-only (u)
    `(progn ,@(->*+!-aux u vs-ss))))

(defmacro ->*+ (u r &rest vs-ss)
  (if vs-ss
      (with-gensyms (w)
        `(let ((,w (->2*+ ,u ,r ,(car vs-ss) ,(cadr vs-ss))))
           ,@(->*+!-aux w (cddr vs-ss))))
      `(->scale ,u ,r)))
