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
  (the long-float (aref u ix)))

(declaim (inline ->[]))
(defun (setf ->[]) (val u ix )
  (declare (type vector-real u))
  (setf (aref u ix) (coerce val 'long-float)))

(declaim (inline ->make))
(defun ->make (n)
  (make-array n :element-type 'long-float))

(declaim (inline ->make-as))
(defun ->make-as (u)
  (declare (type vector-real u))
  (->make (->dim u)))

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
  (let* ((v (->make (length args))))
    (do ((args args (cdr args))
         (i 0 (1+ i)))
        ((null args) v)
      (setf (->[] v i) (car args)))))

(defun first-group (n list)
  (let ((acu nil))
    (do ((i 0 (1+ i))
         (list list (cdr list)))
        ((or (>= i n)
             (null list)) (values (nreverse acu) list))
      (setf acu (cons (car list) acu)))))

(defun map-group (n f list)
  (labels ((map-group1 (n f list acu)
             (multiple-value-bind (group list) (first-group n list)
               (if group
                   (map-group1 n f list (cons (apply f group)  acu))
                   (nreverse acu)))))
    (map-group1 n f list nil)))
    

(defmacro dovector ((&rest head) &body body)
  (destructuring-bind (i vs &optional ret) (if (consp (car head)) `(,(gensym) ,@head) head)
    (let ((vs (map-group 2 #'(lambda (v x) (list (gensym) v x)) vs)))
      `(let (,@(mapcar #'(lambda (v) `(,(car v) ,(caddr v))) vs))
         (dotimes (,i (->dim ,(caar vs)) ,ret)
           (symbol-macrolet (,@(mapcar #'(lambda (v) `(,(cadr v) (->[] ,(car v) ,i))) vs))
             ,@body))))))

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
          (let ((w (->make-as u)))
            (declare (type vector-real w))
            (dovector ((ux u wx w) w)
              (setf wx (,op ux)))))

        (defun ,->1op! (u)
          (declare (type vector-real u))
          (dovector ((ux u) u)
            (setf ux (,op ux))))

        (defun ,->2op (u v)
          (declare (type vector-real u v))
          (let ((w (->make-as u)))
            (declare (type vector-real w))
            (dovector ((ux u vx v wx w) w)
              (setf wx (,op ux vx)))))

        (defun ,->2op! (u v)
          (declare (type vector-real u v))
          (dovector ((ux u vx v) u)
            (setf ux (,op ux vx))))

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
              (if (cdr vs)
                  (with-gensyms (w)
                    `(let ((,w (,',->2op ,u ,(car vs))))
                       ,@(mapcar #'(lambda (v) `(,',->2op! ,w ,v)) (cdr vs))))
                  `(,',->2op ,u ,(car vs)))
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
  (let ((r (coerce r 'long-float))
        (w (->make-as u)))
    (dovector ((ux u wx w) w)
      (setf wx (* r ux)))))

(declaim (inline ->scale!))
(defun ->scale! (u r)
  (declare (type vector-real u))
  (let ((r (coerce r 'long-float)))
    (dovector ((ux u) u)
      (setf ux (* r ux)))))

(declaim (inline ->*))
(defun ->* (u vr)
  (declare (type vector-real u))
  (typecase vr
    (vector-real (->. u vr))
    (t (->scale u vr))))

(declaim (inline ->.))
(defun ->. (u v)
  (declare (type vector-real u v))
  (let ((acu 0.0d0))
    (dovector ((ux u vx v) acu)
      (incf acu (* ux vx)))))
          
(declaim (inline ->/))
(defun ->/ (u r)
  (declare (type vector-real u))
  (let ((inv-r (/ 1.0d0 (coerce r 'long-float)))
        (w (->make-as u)))
    (dovector ((ux u wx w) w)
      (setf wx (* inv-r ux)))))

(declaim (inline ->/!))
(defun ->/! (u r)
  (declare (type vector-real u))
  (let ((inv-r (/ 1.0d0 (coerce r 'long-float))))
    (dovector ((ux u) u)
      (setf ux (* inv-r ux)))))

(declaim (inline ->2*+!))
(defun ->2*+! (u v s)
  (declare (type vector-real u v))
  (let ((s (coerce s 'long-float)))
    (dovector ((ux u vx v) u)
      (incf ux (* s vx)))))

(declaim (inline ->2*+))
(defun ->2*+ (u r v s)
  (declare (type vector-real u v))
  (let ((r (coerce r 'long-float))
        (s (coerce s 'long-float))
        (w (->make-as u)))
    (dovector ((ux u vx v wx w) w)
      (setf wx (+ (* r ux) (* s vx))))))

(defun ->@*+ (us rs)
  (let ((acu (->scale (car us) (car rs))))
    (do ((us (cdr us) (cdr us))
         (rs (cdr rs) (cdr rs)))
        ((null us) acu)
      (->2*+! acu (car us) (car rs)))))

(defmacro ->*+! (u &rest vs-ss)
  (labels ((->*+!-aux (u vs-ss)
             (if vs-ss
                 `( (->2*+! ,u ,(car vs-ss) ,(cadr vs-ss))
                    ,@(->*+!-aux u (cddr vs-ss)))
                 `(,u))))
    (once-only (u)
      `(progn ,@(->*+!-aux u vs-ss)))))

(defmacro ->*+ (u r &rest vs-ss)
  (if vs-ss
      (with-gensyms (w)
        `(let ((,w (->2*+ ,u ,r ,(car vs-ss) ,(cadr vs-ss))))
           ,@(->*+!-aux w (cddr vs-ss))))
      `(->scale ,u ,r)))

(declaim (inline *2))
(defun **2 (x)
  (let ((x (coerce x 'long-float)))
    (* x x)))

(declaim (inline ->norm2))
(defun ->norm2 (u)
  (declare (type vector-real u))
  (let ((acu 0.0d0))
    (dovector ((x u) acu)
      (incf acu (**2 x)))))

(declaim (inline ->norm))
(defun ->norm (u)
  (declare (type vector-real u))
  (sqrt (->norm2 u)))

(declaim (inline ->dist2))
(defun ->dist2 (u v)
  (declare (type vector-real u v))
  (let ((acu 0.0d0))
    (dovector ((ux u vx v) acu)
      (incf acu (**2 (- vx ux))))))

(declaim (inline ->dist))
(defun ->dist (u v)
  (declare (type vector-real u v))
  (sqrt (->dist2 u v)))

(declaim (inline ->norm-chebyshev))
(defun ->norm-chebyshev (u)
  (declare (type vector-real u))
  (let ((acu 0.0d0)
        (ix 0))
    (dovector (i (x u) (values acu ix))
      (let ((abs-x (abs x)))
        (when (> abs-x acu)
          (setf acu abs-x ix i))))))

(declaim (inline ->dist-chebyshev))
(defun ->dist-chebyshev (u v)
  (declare (type vector-real u v))
  (let ((acu 0.0d0)
        (ix 0))
    (dovector (i (ux u vx v) (values acu ix))
      (let ((dx (abs (- vx ux))))
        (when (> dx acu)
          (setf acu dx ix i))))))

(declaim (inline ->norm-manhattan))
(defun ->norm-manhattan (u)
  (declare (type vector-real u))
  (let ((acu 0.0d0))
    (dovector ((x u) acu)
      (incf acu (abs x)))))

(declaim (inline ->dist-manhattan))
(defun ->dist-manhattan (u v)
  (declare (type vector-real u v))
  (let ((acu 0.0d0))
    (dovector ((ux u vx v) acu)
      (incf acu (abs (- vx ux))))))

(declaim (inline ->versor))
(defun ->versor (u &optional (magnitude 1.0d0))
  (declare (type vector-real u))
  (let ((w (->make-as u))
        (inv-d (/ (coerce magnitude 'long-float) (->norm u))))
    (dovector ((ux u wx w) w)
      (setf wx (* inv-d ux)))))

(declaim (inline ->versorize!))
(defun ->versorize! (u &optional (magnitude 1.0d0))
  (declare (type vector-real u))
  (let ((inv-d (/ (coerce magnitude 'long-float) (->norm u))))
    (dovector ((ux u) u)
      (setf ux (* inv-d ux)))))

(declaim (inline ->angle))
(defun ->angle (u v)
  (declare (type vector-real u v))
  (let ((un2 0.0d0)
        (vn2 0.0d0)
        (dot 0.0d0))
    (dovector ((ux u vx v) (/ dot (sqrt (* un2 vn2))))
      (incf un2 (**2 ux))
      (incf vn2 (**2 vx))
      (incf dot (**2 ux)))))

(declaim (inline ->angle0))
(defun ->angle0 (u v)
  "Returns the angle formed by the two vectors. Returns zero if any of then is the zero vector"
  (declare (type vector-real u v))
  (let ((un2 0.0d0)
        (vn2 0.0d0)
        (dot 0.0d0))
    (dovector ((ux u vx v) (if dot (/ dot (sqrt (* un2 vn2))) 0.0d0))
      (incf un2 (**2 ux))
      (incf vn2 (**2 vx))
      (incf dot (**2 ux)))))

(declaim (inline ->2box))
(defun ->2box (u v)
  (declare (type vector-real u v))
  (let ((c0 (->make-as u))
        (c1 (->make-as v)))
    (dovector ((ux u vx v x0 c0 x1 c1) (values c0 c1))
      (if (<= ux vx)
          (setf x0 ux x1 vx)
          (setf x0 vx x1 ux)))))

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
  (dovector ((x v x0 c0 x1 c1) (values c0 c1))
    (cond ((< x x0) (setf x0 x))
          ((> x x1) (setf x1 x)))))
    
(defmacro ->box! (c0 c1 &rest vs)
  (cond ((null vs) `(values ,c0 ,c1))
        (t (with-gensyms (i x0 x1 x)
             (let ((vs (mapcar #'(lambda (v) `(,(gensym) ,v)) vs)))
               (once-only (c0 c1)
                 `(let ,vs
                    (dovector (,i (,x0 ,c0 ,x1 ,c1) (values ,c0 ,c1))
                      ,@(mapcar #'(lambda (v)
                                    `(let ((,x (->[] ,(car v) ,i)))
                                       (cond ((< ,x ,x0) (setf ,x0 ,x))
                                             ((> ,x ,x1) (setf ,x1 ,x))))) vs)))))))))

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

(declaim (inline ->volume))
(defun ->volume (u)
  (declare (type vector-real u))
  (let ((acu 1.0d0))
    (dovector ((x u) acu)
      (setf acu (* acu x)))))

(declaim (inline ->box-volume))
(defun ->box-volume (c0 c1)
  (declare (type vector-real c0 c1))
  (let ((acu 1.0d0))
    (dovector ((x0 c0 x1 c1) acu)
      (setf acu (* acu (- x1 x0))))))

(defun ->box-split (c0 c1)
  (declare (type vector-real c0 c1))
  (multiple-value-bind (d i) (->dist-chebyshev c0 c1)
    (declare (ignorable d))
    (let ((b0-c1 (->clone c1))
          (b1-c0 (->clone c0))
          (x (* 0.5d0 (+ (->[] c0 i) (->[] c1 i)))))
      (setf (->[] b0-c1 i) x
            (->[] b1-c0 i) x)
      (values b0-c1 b1-c0 i x))))

(declaim (inline ->box-dist2))
(defun ->box-dist2 (c0 c1 p)
  (declare (type vector-real c0 c1 p))
  (let ((acu 0.0d0))
    (declare (type long-float acu))
    (dovector ((x p x0 c0 x1 c1) acu)
      (cond ((< x x0) (incf acu (**2 (- x0 x))))
            ((> x x1) (incf acu (**2 (- x x1))))))))

(declaim (inline ->box-max-dist2))
(defun ->box-max-dist2 (c0 c1 u)
  (declare (type vector-real c0 c1 u))
  (let ((acu 0.0d0))
    (declare (type long-float acu))
    (dovector ((x u x0 c0 x1 c1) acu)
      (incf acu (max (**2 (- x x0)) (**2 (- x1 x)))))))

(declaim (inline ->box-boundary-dist2))
(defun ->box-boundary-dist2 (c0 c1 u)
  (declare (type vector-real c0 c1 u))
  (let ((min most-positive-double-float)
        (acu 0.0d0))
    (dovector ((x u x0 c0 x1 c1) (if (> acu 0.0d0) acu (* min min)))
      (cond ((< x x0) (incf acu (**2 (- x x0))))
            ((> x x1) (incf acu (**2 (- x1 x))))
            (t (setf min (min min (- x x0) (- x1 x))))))))

(declaim (inline ->box-random))
(defun ->box-random (c0 c1)
  (declare (type vector-real c0 c1))
  (let ((w (->make-as c0)))
    (dovector ((x0 c0 x1 c1 x w) w)
      (let ((r (random 1.0d0)))
        (setf x (+ (* r x0) (* (- 1.0d0 r) x1)))))))

(defun ->box-box-dist2 (c0 c1 c2 c3)
  (declare (type vector-real c0 c1 c2 c3))
  (let ((acu 0.0d0))
    (declare (type long-float acu))
    (dovector ((x0 c0 x1 c1 x2 c2 x3 c3) acu)
      (cond ((< x1 x2) (incf acu (**2 (- x2 x1))))
            ((> x0 x3) (incf acu (**2 (- x0 x3))))))))

(defmacro mapcar-with-index (function list)
  (once-only (function)
    (with-gensyms (tail ix map)
      `(do ((,tail ,list (cdr ,tail))
            (,ix 0 (1+ ,ix))
            (,map nil))
           ((null ,tail) (reverse ,map))
         (setf ,map (cons (funcall ,function (car ,tail) ,ix) ,map))))))

(defmacro ->mix (&rest vs)
  (with-gensyms (w)
    `(let ((,w (->make ,(length vs))))
       ,@(mapcar-with-index #'(lambda (v i) `(setf (->[] ,w ,i) (->[] ,v ,i))) vs)
       ,w)))
