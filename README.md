# 百度翻译

[百度翻译](https://fanyi.baidu.com) 之 [通用翻译 API](http://api.fanyi.baidu.com/api/trans/product/prodinfo) 的 Emacs 接口。

## 使用

申请通用翻译 API 之后，需要设置 APP ID 和密钥。`baidu-fanyi.el` 首次加载会尝试从 `~/.authinfo[.gpg]` 读取：

    machine fanyi.baidu.com login APIID password SECRETKEY

你也可以从 Lisp 设置：

``` emacs-lisp
(setq baidu-fanyi-appid "APP ID"
      baidu-fanyi-secretkey "密钥")
```

### `(baidu-fanyi-request Q FROM TO)`

把 `Q` 从 `FROM` 语言翻译成 `TO` 语言，返回一个 alist：

``` emacs-lisp
(baidu-fanyi-request "筋疲力尽" "zh" "en")
;; => ((from . "zh") (to . "en") (trans_result ((src . "筋疲力尽") (dst . "Exhaustion"))))
```

#### 换行问题

包含换行相当于翻译多个文本：

``` emacs-lisp
(baidu-fanyi-request "hello\nworld" "auto" "zh")
;; =>
((from . "en")
 (to . "zh")
 (trans_result
  ((src . "hello") (dst . "你好"))
  ((src . "world") (dst . "世界"))))
```

不包含换行：

``` emacs-lisp
(baidu-fanyi-request "hello\\nworld" "auto" "zh")
;; => 
((from . "en")
 (to . "zh")
 (trans_result
  ((src . "hello\\nworld") (dst . "你好\\n沃德"))))
```

### `M-x baidu-fanyi-simple Q FROM TO`

同上，在 Minibuffer 显示译文。

### `M-x baidu-fanyi-chinese-english Q`

中英文互译。

## 资源

- [通用翻译 API 申请](http://api.fanyi.baidu.com/api/trans/product/prodinfo) (每个月 200 万字符的免费额度，比如源语言平均包含 200 字符，一个月可以免费用 10000 次)
- [百度翻译 API 文档](http://api.fanyi.baidu.com/api/trans/product/apidoc)
