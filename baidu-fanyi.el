;;; baidu-fanyi.el --- 百度通用翻译 API 封装 (Baidu Translate API Wrapper)  -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Xu Chunyang

;; Author: Xu Chunyang <mail@xuchunyang.me>
;; Homepage: https://github.com/xuchunyang/baidu-fanyi.el
;; Package-Requires: ((emacs "25.1"))
;; Version: 0

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; 在 Emacs 中使用百度翻译之通用翻译 API

;;; Code:

(require 'url)
(require 'json)
(require 'auth-source)

(eval-when-compile (require 'subr-x))   ; `when-let'

(defvar url-http-response-status)

(defvar baidu-fanyi-appid
  (let ((plist (car (auth-source-search :max 1 :host "fanyi.baidu.com"))))
    (plist-get plist :user))
  "通用翻译 API 的 APP ID.")

(defvar baidu-fanyi-secretkey
  (let ((plist (car (auth-source-search :max 1 :host "fanyi.baidu.com"))))
    (let ((v (plist-get plist :secret)))
      (if (functionp v) (funcall v) v)))
  "通用翻译 API 的密钥.")

(defvar baidu-fanyi-endpoint
  (if (gnutls-available-p)
      "https://fanyi-api.baidu.com/api/trans/vip/translate"
    "http://api.fanyi.baidu.com/api/trans/vip/translate"))

(defvar baidu-fanyi-user-aguent
  "baidu-fanyi.el (https://github.com/xuchunyang/baidu-fanyi.el)")

(define-error 'baidu-fanyi-error "Baidu-Fanyi Error" 'error)
(define-error 'baidu-fanyi-http-error "HTTP Error" 'baidu-fanyi-error)

(defun baidu-fanyi-salt ()
  ;; [32768, 32768*2]
  (+ 32768 (random (1+ 32768))))

(defun baidu-fanyi-sign (q salt)
  (md5 (concat baidu-fanyi-appid q salt baidu-fanyi-secretkey)))

(defun baidu-fanyi-request (q from to)
  (unless (and baidu-fanyi-appid baidu-fanyi-secretkey)
    (user-error "Please set `baidu-fanyi-appid' and `baidu-fanyi-secretkey'"))

  (let ((url-user-agent baidu-fanyi-user-aguent)
        (url-show-status nil)
        (url-request-method "POST")
        (url-request-extra-headers
         '(("Content-Type" . "application/x-www-form-urlencoded")))
        (url-request-data
         (encode-coding-string
          (mapconcat
           (pcase-lambda (`(,key . ,val))
             (format
              "%s=%s"
              (url-hexify-string (symbol-name key))
              (url-hexify-string val)))
           (let ((salt (number-to-string (baidu-fanyi-salt))))
             `((q . ,q)
               (from . ,from)
               (to . ,to)
               (appid . ,baidu-fanyi-appid)
               (salt . ,salt)
               (sign . ,(baidu-fanyi-sign q salt))))
           "&")
          'utf-8))
        result)
    (with-current-buffer (url-retrieve-synchronously baidu-fanyi-endpoint)
      (unless (= url-http-response-status 200)
        (signal 'baidu-fanyi-http-error (list (buffer-string))))

      (goto-char (point-min))
      (re-search-forward "^\r?\n")
      (let ((json-object-type 'alist)
            (json-array-type  'list)
            (json-key-type    'symbol)
            (json-false       nil)
            (json-null        nil))
        (setq result (json-read)))

      ;; success {"from":"en","to":"zh","trans_result":[{"src":"hello","dst":"\u4f60\u597d"}]}
      ;; failure {"error_code":"58001","error_msg":"INVALID_TO_PARAM"}
      (when-let ((error-msg (alist-get 'error_msg result)))
        (signal 'baidu-fanyi-error (list error-msg)))

      result)))

(defconst baidu-fanyi-langs-alist
  ;; 语言简写 - 名称
  '(("auto" . "自动检测")
    ("zh"   . "中文")
    ("en"   . "英语")
    ("yue"  . "粤语")
    ("wyw"  . "文言文")
    ("jp"   . "日语")
    ("kor"  . "韩语")
    ("fra"  . "法语")
    ("spa"  . "西班牙语")
    ("th"   . "泰语")
    ("ara"  . "阿拉伯语")
    ("ru"   . "俄语")
    ("pt"   . "葡萄牙语")
    ("de"   . "德语")
    ("it"   . "意大利语")
    ("el"   . "希腊语")
    ("nl"   . "荷兰语")
    ("pl"   . "波兰语")
    ("bul"  . "保加利亚语")
    ("est"  . "爱沙尼亚语")
    ("dan"  . "丹麦语")
    ("fin"  . "芬兰语")
    ("cs"   . "捷克语")
    ("rom"  . "罗马尼亚语")
    ("slo"  . "斯洛文尼亚语")
    ("swe"  . "瑞典语")
    ("hu"   . "匈牙利语")
    ("cht"  . "繁体中文")
    ("vie"  . "越南语")))

(defun baidu-fanyi-read-lang-annotation (id)
  (let ((name (cdr (assoc id baidu-fanyi-langs-alist))))
    (when name
      (format " (%s)" name))))

(defun baidu-fanyi-read-lang (prompt &optional def)
  (let ((completion-ignore-case t))
    (completing-read
     prompt
     (lambda (string pred action)
       (pcase action
         ('metadata
          '(metadata
            (annotation-function . baidu-fanyi-read-lang-annotation)))
         (_ (complete-with-action
             action (mapcar #'car baidu-fanyi-langs-alist) string pred))))
     nil t nil nil def)))

;;;###autoload
(defun baidu-fanyi-simple (q from to)
  "百度翻译的一个简单应用.

Q    请求翻译 Query
FROM 翻译源语言 (可以设置为 auto，代表自动检测)
TO   译文语言

返回译文.
"
  (interactive
   (let ((q (read-string "百度翻译: "))
         (from (baidu-fanyi-read-lang "翻译源语言 (default auto): " "auto"))
         (to (baidu-fanyi-read-lang "译文语言: ")))
     (list q from to)))
  (let* ((data (baidu-fanyi-request q from to))
         (result (alist-get 'dst (car (alist-get 'trans_result data)))))
    (message "%s -> %s" q result)
    result))

;;;###autoload
(defun baidu-fanyi-chinese-english (q)
  "如果 Q 包含中文字符，将 Q 翻译成英文，否则将其翻译成中文."
  (interactive "s百度翻译: ")
  (baidu-fanyi-simple q "auto" (if (string-match-p "\\cC" q) "en" "zh")))

(provide 'baidu-fanyi)
;;; baidu-fanyi.el ends here
