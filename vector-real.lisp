(defpackage "VECTOR-REAL"
  (:nicknames "VR")
  (:use "COMMON-LISP-USER")
  (:use "ALEXANDRIA"))

;(in-package "VECTOR-REAL")

(deftype vector-real (&optional size)
  `(vector long-float ,size))

(declaim (inline ->dim))
(defun ->dim (u)
  (declare (type vector-real u))
  (length u))

(declaim (inline ->[]))
(defun ->[] (u ix)
  (declare (type vector-real u))
  (aref u ix))

(declaim (inline ->[]))
(defun (setf ->[]) (val u ix )
  (declare (type vector-real u))
  (setf (aref u ix) (coerce val 'long-float)))

(declaim (inline ->make))
(defun ->make (n)
  (make-array n :element-type 'long-float))

(declaim (inline ->zero))
(defun ->zero (n)
  (make-array n :element-type 'long-float :initial-element 0.0d0))

(declaim (inline ->cube))
(defun ->cube (n &optional (magnitude 1.0d0))
  (make-array n :element-type 'long-float :initial-element (coerce magnitude 'long-float)))

(declaim (inline ->clone))
(defun ->clone (v)
  (declare (type vector-real v))
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
  (declare (type vector-real u v))
  (dotimes (i (->dim u) u)
    (setf (->[] u i) (->[] v i))))

(defmacro defvop (op)
  (let ((->1op (intern (format nil "->1~s" op)))
        (->1op! (intern (format nil "->1~s!" op)))
        (->2op (intern (format nil "->2~s" op)))
        (->2op! (intern (format nil "->2~s!" op)))
        (->@op (intern (format nil "->@~s" op)))
        (->@op! (intern (format nil "->@~s!" op)))
        (->op (intern (format nil "->~s" op)))
        (->op! (intern (format nil "->~s!" op))))
    `(progn
       (declaim (inline ,->2op)
                (inline ,->2op!)
                (inline ,->1op)
                (inline ,->1op!)
                (inline ,->@op)
                (inline ,->@op!))
       (values
        (defun ,->1op (u)
          (declare (type vector-real u))
          (let* ((n (length u))
                (w (->make n)))
            (declare (type vector-real w))
            (dotimes (i n w)
              (setf (->[] w i) (,op (->[] u i))))))

        (defun ,->1op! (u)
          (declare (type vector-real u))
          (let ((n (length u)))
            (dotimes (i n u)
              (setf (->[] u i) (,op (->[] u i))))))

        (defun ,->2op (u v)
          (declare (type vector-real u v))
          (let* ((n (length u))
                 (w (->make n)))
            (declare (type vector-real w))
            (dotimes (i n w)
              (setf (->[] w i) (,op (->[] u i) (->[] v i))))))

        (defun ,->2op! (u v)
          (declare (type vector-real u v))
          (let ((n (length u)))
            (dotimes (i n u)
              (setf (->[] u i) (,op (->[] u i) (->[] v i))))))

        (defun ,->@op (us)
          (when us
            (let ((w (->clone (car us)))
                  (us (cdr us)))
              (dolist (u us w)
                (,->2op! w u)))))

        (defun ,->@op! (u vs)
          (declare (type vector-real u))
          (dolist (v vs u)
            (,->2op! u v)))

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
  (declare (type vector-real u))
  (let* ((r (coerce r 'long-float))
         (n (->dim u))
         (w (->make n)))
    (dotimes (i n w)
      (setf (->[] w i) (* (->[] u i) r)))))

(declaim (inline ->scale!))
(defun ->scale! (u r)
  (declare (type vector-real u))
  (let* ((r (coerce r 'long-float)))
    (dotimes (i (->dim u) u)
      (setf (->[] u i) (* (->[] u i) r)))))

(declaim (inline ->*))
(defun ->* (a b)
  (typecase a
    (vector-real (->scale a b))
    (t (->scale b a))))

(declaim (inline ->.))
(defun ->. (u v)
  (declare (type vector-real u v))
  (let ((acu 0)
        (n (->dim u)))
    (dotimes (i n acu)
      (incf acu (* (->[] u i) (->[] v i))))))

(declaim (inline ->/))
(defun ->/ (u r)
  (declare (type vector-real u))
  (let* ((inv-r (/ 1.0d0 (coerce r 'long-float)))
         (n (->dim u))
         (w (->make n)))
    (dotimes (i n w)
      (setf (->[] w i) (* (->[] u i) inv-r)))))

(declaim (inline ->/!))
(defun ->/! (u r)
  (declare (type vector-real u))
  (let* ((inv-r (/ 1.0d0 (coerce r 'long-float))))
    (dotimes (i (->dim u) u)
      (setf (->[] u i) (* (->[] u i) inv-r)))))

(declaim (inline ->2*+!))
(defun ->2*+! (u v s)
  (declare (type vector-real u v))
  (let ((s (coerce s 'long-float)))
    (dotimes (i (->dim u) u)
      (incf (->[] u i) (* (->[] v i) s)))))

(declaim (inline ->2*+))
(defun ->2*+ (u r v s)
  (declare (type vector-real u v))
  (let* ((r (coerce r 'long-float))
         (s (coerce s 'long-float))
         (n (->dim u))
         (w (->make n)))
    (dotimes (i n w)
      (setf (->[] w i) (+ (* (->[] u i) r) (* (->[] v i) s))))))

(defun ->@*+ (us rs)
  (let ((acu (->scale (car us) (car rs))))
    (do ((us (cdr us) (cdr us))
         (rs (cdr rs) (cdr rs)))
        ((null us) acu)
      (->2*+! acu (car us) (car rs)))))

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

(declaim (inline ->norm2))
(defun ->norm2 (u)
  (declare (type vector-real u))
  (let ((acu 0.0d0))
    (dotimes (i (->dim u) acu)
      (let ((x (->[] u i)))
        (incf acu (* x x))))))

(declaim (inline ->norm))
(defun ->norm (u)
  (declare (type vector-real u))
  (sqrt (->norm2 u)))

(declaim (inline ->dist2))
(defun ->dist2 (u v)
  (declare (type vector-real u v))
  (let ((acu 0.0d0))
    (dotimes (i (->dim u) acu)
      (let ((dx (- (->[] u i) (->[] v i))))
        (incf acu (* dx dx))))))

(declaim (inline ->dist))
(defun ->dist (u v)
  (declare (type vector-real u v))
  (sqrt (->dist2 u v)))

(declaim (inline ->norm-chebyshev))
(defun ->norm-chebyshev (u)
  (declare (type vector-real u))
  (let ((acu 0.0d0)
        (ix 0))
    (dotimes (i (->dim u) (values acu ix))
      (let ((x (abs (->[] u i))))
        (when (> x acu)
          (setf acu x ix i))))))

(declaim (inline ->dist-chebyshev))
(defun ->dist-chebyshev (u v)
  (declare (type vector-real u v))
  (let ((acu 0.0d0)
        (ix 0))
    (dotimes (i (->dim u) (values acu ix))
      (let ((dx (abs (- (->[] u i) (->[] v i)))))
        (when (> dx acu)
          (setf acu dx ix i))))))

(declaim (inline ->norm-manhattan))
(defun ->norm-manhattan (u)
  (declare (type vector-real u))
  (let ((acu 0.0d0))
    (dotimes (i (->dim u) acu)
      (incf acu (abs (->[] u i))))))

(declaim (inline ->dist-manhattan))
(defun ->dist-manhattan (u v)
  (declare (type vector-real u v))
  (let ((acu 0.0d0))
    (dotimes (i (->dim u) acu)
      (incf acu (abs (- (->[] u i) (->[] v i)))))))

(declaim (inline ->versor))
(defun ->versor (u &optional (magnitude 1.0d0))
  (declare (type vector-real u))
  (let* ((n (->dim u))
         (w (->make n))
         (inv_d (/ (coerce magnitude 'long-float) (->dim u))))
    (dotimes (i n w)
      (setf (->[] w i) (* inv_d (->[] u i))))))

(declaim (inline ->versorize))
(defun ->versorize! (u &optional (magnitude 1.0d0))
  (declare (type vector-real u))
  (let ((inv_d (/ (coerce magnitude 'long-float) (->dim u))))
    (dotimes (i (->dim u) u)
      (setf (->[] u i) (* inv_d (->[] u i))))))

(declaim (inline ->angle))
(defun ->angle (u v)
  (declare (type vector-real u v))
  (let ((un2 0.0d0)
        (vn2 0.0d0)
        (dot 0.0d0))
    (dotimes (i (->dim u) (/ dot (sqrt (* un2 vn2))))
      (let ((ux (->[] u i))
            (vx (->[] v i)))
        (incf un2 (* ux ux))
        (incf vn2 (* vx vx))
        (incf dot (* ux vx))))))

(declaim (inline ->2box))
(defun ->2box (u v)
  (declare (type vector-real u v))
  (let* ((n (->dim u))
         (c0 (->make n))
         (c1 (->make n)))
    (dotimes (i n (values c0 c1))
      (let ((ux (->[] u i))
            (vx (->[] v i)))
        (if (< ux vx)
            (setf (->[] c0 i) ux (->[] c1 i) vx)
            (setf (->[] c0 i) vx (->[] c1 i) ux))))))

(defmacro ->box (u &rest vs)
  (cond ((null vs) (once-only (u)
                     `(values (->clone ,u) (->clone ,u))))

        ((null (cdr vs)) `(->2box ,u ,(car vs)))

        (t (with-gensyms (n c0 c1 x0 x1 x i)
             (let ((vs (mapcar #'(lambda (v)
                                   `(,(gensym) ,v)) vs)))
               (once-only (u)
                 `(let* ((,n (->dim ,u))
                         (,c0 (->make ,n))
                         (,c1 (->make ,n))
                         ,@vs)
                    (dotimes (,i ,n (values ,c0 ,c1))
                      (let* ((,x0 (->[] ,u ,i))
                             (,x1 ,x0))
                        ,@(mapcar #'(lambda (v)
                                      `(let ((,x (->[] ,(car v) ,i)))
                                         (cond ((< ,x ,x0) (setf ,x0 ,x))
                                               ((> ,x ,x1) (setf ,x1 ,x))
                                               (t)))) vs)
                        (setf (->[] ,c0 ,i) ,x0
                              (->[] ,c1 ,i) ,x1))))))))))

(defun ->3box! (c0 c1 v)
  (declare (type vector-real c0 c1 v))
  (dotimes (i (->dim c0) (values c0 c1))
    (let ((x (->[] v i)))
      (cond ((< x (->[] c0 i)) (setf (->[] c0 i) x))
            ((> x (->[] c1 i)) (setf (->[] c1 i) x))
            (t)))))

(defmacro ->box! (c0 c1 &rest vs)
  (cond ((null vs) `(values ,c0 ,c1))
        (t (with-gensyms (i x0 x1 x)
             (let ((vs (mapcar #'(lambda (v) `(,(gensym) ,v)) vs)))
               (once-only (c0 c1)
                 `(let ,vs
                    (dotimes (,i (->dim ,c0) (values ,c0 ,c1))
                      (let ((,x0 (->[] ,c0 ,i))
                            (,x1 (->[] ,c1 ,i)))
                        ,@(mapcar #'(lambda (v)
                                      `(let ((,x (->[] ,(car v) ,i)))
                                         (cond ((< ,x ,x0) (setf (->[] ,c0 ,x))
                                                (> ,x ,x1) (setf (->[] ,c1 ,x)))))) vs))))))))))

(declaim (inline ->@box))
(defun ->@box (us)
  (when us
    (let ((u (car us))
          (vs (cdr us)))
      (if vs
          (multiple-value-bind (c0 c1) (->2box u (car vs))
            (dolist (v (cdr vs) (values c0 c1))
              (->3box! c0 c1 v)))
          (values (->clone u) (->clone u))))))

(declaim (inline -3>x))
(defun -3>x (u v)
  (declare (type vector-real u v))
  (let ((w (->make 3)))
    (setf (->[] w 0) (- (* (->[] u 0) (->[] v 1))
                        (* (->[] u 1) (->[] v 0)))
          (->[] w 1) (- (* (->[] u 1) (->[] v 2))
                        (* (->[] u 2) (->[] v 1)))
          (->[] w 2) (- (* (->[] u 2) (->[] v 0))
                        (* (->[] u 0) (->[] v 2))))
    w))

(declaim (inline -3>rotate))
(defun -3>rotate(u a angle)
  (declare (type vector-real u a))
  (let* ((angle (coerce angle 'long-float))
         (w (->make 3))
         (n_inv (/ 1.0d0 (->norm a)))
         (s (sin angle))
         (c (cos angle))
         (cc (- 1.0d0 c))
         (ux (->[] u 0))
         (uy (->[] u 1))
         (uz (->[] u 2))
         (ax (* n_inv (->[] a 0)))
         (ay (* n_inv (->[] a 1)))
         (az (* n_inv (->[] a 2))))
    (declare (type long-float n_inv s c cc ux uy uz ax ay az)
             (type vector-real w))
    (setf (->[] w 0) (+ (* ux (+ (* ax ax cc) c))
                        (* uy (- (* ax ay cc) (* az s)))
                        (* uz (+ (* ax az cc) (* ay s))))
          (->[] w 1) (+ (* ux (+ (* ay ax cc) (* az s)))
                        (* uy (+ (* ay ay cc) c))
                        (* uz (- (* ay az cc) (* ax s))))
          (->[] w 2) (+ (* ux (- (* az ax cc) (* ay s)))
                        (* uy (+ (* az ay cc) (* ax s)))
                        (* uz (+ (* az az cc) c))))
    w))





