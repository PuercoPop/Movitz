# Build instructions

```lisp
(require 'movitz) ;; Or (ql:quickload movitz)
(create-image)
(movitz:dump-image :path "foo.img")
```

finally
```
qemu -fda foo.img -boot a
```
