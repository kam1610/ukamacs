;; ukamacs.el
;; (deferred:clear-queue)

(require 'deferred)
(require 'concurrent)

(defun ukmc-init ()
  (setq ukmc-ghost-path             "z:\\home\\kosame\\src\\ukamacs\\ghost\\fairyWings\\")
  (setq ukmcSurfacesBuf             nil)
  (setq ukmcEvtSem                  (cc:semaphore-create 1))
  (setq ukmcEvtBuf                  (get-buffer-create "ukmcEvtBuf"))
  (setq ukmcRcvBuf                  (get-buffer-create "ukmcRcvBuf"))
  (setq ukmc-proc-buf               (get-buffer-create "ukmcProcBuf"))
  (setq ukmc-baloon-buf             (get-buffer-create "ukamacs"))
  (with-current-buffer ukmcEvtBuf    (erase-buffer))
  (with-current-buffer ukmcRcvBuf    (erase-buffer))
  (with-current-buffer ukmc-proc-buf (erase-buffer))
  (setq ukmc-window-height          8)
  (setq ukmc-on-choice-timeout      15)
  (setq ukmc-proc-buf-pos           1)
  (setq ukmc-selected-data          nil)
  (setq ukmcCanPlay                 "1")
  (setq ukmcOnSecCount              0)
  (setq ukmc-process-name-base      "shioricaller-mti.exe")
  (setq ukmc-process-name           nil)
  (setq ukmc-talk-scope-list        '("法子" "シルフィ" "" "" ""))
  (setq ukmc-surface-list           [-1 -1 -1 -1 -1])
  (setq ukmc-talk-scope             0)
  (setq ukmc-scope-change-interval  300)
  (setq ukmc-decoration-list        nil)
  (setq ukmc-on-choice-dataflow     (cc:dataflow-environment))
  (setq ukmc-surface-collision-hash (make-hash-table))
  (setq ukmc-close-flag             nil)
  (global-set-key "\C-cud" 'ukmc-on-mouse-double-click)
  (global-set-key "\C-cuw" 'ukmc-on-mouse-wheel)

  (copy-face 'button 'ukmc-question-face)
  (defvar ukmc-mode-map nil)
  (unless ukmc-mode-map
    (let ((map (make-sparse-keymap)))
      (define-key map "n" 'next-line)
      (define-key map "p" 'previous-line)
      (define-key map "q" 'ukmc-close-window)
      (define-key map "\r" 'ukmc-click-text)
      (setq ukmc-mode-map map)))
  (ukmc-clear-client-processes)
  (setq ukmc-client-process (start-process
                             ukmc-process-name-base
                             ukmc-proc-buf
                             (concat ukmc-ghost-path "..\\..\\" ukmc-process-name-base)
                             (concat ukmc-ghost-path "ghost\\master\\yaya.dll")
                             (concat ukmc-ghost-path "ghost\\master\\")))
  )

(defun ukmc ()
  (interactive)
  (ukmc-clear-client-processes)
  (ukmc-init)
  (ukmc-make-surface-collisions)
  (ukmc-show)
  (ukmc-onboot)
  (ukmc-onsec-loop)
  )

;; ukmc-show ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-show ()
  (interactive)
  (set-buffer ukmc-baloon-buf)
  (unless (derived-mode-p 'ukmc-mode)
    (ukmc-mode))

  (if (get-buffer-window (current-buffer))
      (select-window (get-buffer-window (current-buffer)))
    (let ((w (get-largest-window)))
      (if (and pop-up-windows
               (> (window-height w)
                  (+ window-min-height ukmc-window-height 2)))
          (progn
            (setq w (split-window w
                                  (- (window-height w)
                                     ukmc-window-height 2)
                                  nil))
            (set-window-buffer w (current-buffer))
            (select-window w))
        (pop-to-buffer (current-buffer)))))
  )

;; ukmc-close-window ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-close-window ()
  (interactive)
  (if (and (get-buffer-window ukmc-baloon-buf)
           (not (one-window-p t)))
      (progn
        (select-window (get-buffer-window ukmc-baloon-buf))
        (delete-window (get-buffer-window ukmc-baloon-buf)))))

;; ukmc-wait-for-shiori-response ;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-wait-for-shiori-response ()
  (with-current-buffer ukmc-proc-buf
    (goto-char ukmc-proc-buf-pos)
    (cond
     ( ;; \e
      (re-search-forward "^Value: .*$" (point-max) t 1)
      t)
     ( ;; No Content
      (re-search-forward "SHIORI/3.0 +204 +No Content"
                         (point-max) t 1)
      (setq ukmc-proc-buf-pos (point))
      t)
     ( ;; wait
      t
      (deferred:nextc (deferred:wait 200) 'ukmc-wait-for-shiori-response))
     )
    )
  )

;; ukmc-onboot ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-onboot ()
  (cc:semaphore-acquire ukmcEvtSem)
  (process-send-string
   (process-name ukmc-client-process)
   "GET SHIORI/3.0\nID: OnBoot\n\n")
  (deferred:$
    (deferred:next 'ukmc-wait-for-shiori-response)
    (deferred:nextc it 'ukmc-crawl-proc-buf)
    (deferred:nextc it
      (lambda () (cc:semaphore-release ukmcEvtSem))))
)

;; ukmc-close ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-close ()
  (interactive)
  (cc:semaphore-acquire ukmcEvtSem)
  (process-send-string
   (process-name ukmc-client-process)
   "GET SHIORI/3.0\nID: OnClose\n\n")
  (deferred:$
    (deferred:next 'ukmc-wait-for-shiori-response)
    (deferred:nextc it 'ukmc-crawl-proc-buf)
    (deferred:nextc it (lambda ()
                         (setq ukmc-close-flag t)
                         (process-send-string
                          ukmc-client-process
                          ".\n\n")))
    (deferred:nextc it
      (lambda () (cc:semaphore-release ukmcEvtSem))))
)

;; ukmc-clear-client-processes ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-clear-client-processes ()
  (mapcar
   (lambda (x)
     (if (string-match "ukamacs\\.exe" (process-name x))
         (progn
           (process-send-string
            (process-name x)
            "GET SHIORI/3.0\nID: OnClose\n\n")
           (process-send-string
            (process-name x)
            ".\n\n"))))
   (process-list)))

;; ukmc-mode ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-mode ()
  (interactive)
  (use-local-map ukmc-mode-map)
  (setq major-mode 'ukmc-mode)
  (setq mode-name "Ukamacs")
  (run-hooks 'ukmc-mode-hook))

;; ukmc-talk-set-and-show-talker ;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-talk-set-and-show-talker (talker-id)
  (setq ukmc-talk-scope talker-id)
  (goto-char (point-max))
  (insert "\n")
  (insert (format "%s(%d): "
                  (nth ukmc-talk-scope ukmc-talk-scope-list)
                  (aref ukmc-surface-list ukmc-talk-scope))))


;; ukmc-talk-exec-func ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-talk-exec-func ()
  (let ((ret      nil)
        (interval   0)
        (pos      nil)
        (prop     nil))
    (with-current-buffer ukmc-baloon-buf
      (setq ret (ukmc-scan-command))
      (set-buffer "ukamacs")
      (setq interval 10)
      (goto-char (point-max))
      (insert (nth 1 ret))

      (cond
       ;; yen e- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       ((string= (car ret) "\\e")
        (insert "\n----\n")
        (if ukmc-decoration-list
            (progn
              (while (setq prop (pop ukmc-decoration-list))
                (put-text-property (nth 0 prop) (nth 1 prop) 'qid  (nth 2 prop))
                (put-text-property (nth 0 prop) (nth 1 prop) 'face (nth 3 prop)))
              (deferred:$
                (deferred:timeout
                  (* ukmc-on-choice-timeout 1000) nil
                  (deferred:nextc (cc:dataflow-get ukmc-on-choice-dataflow 'choice)
                    (lambda (x) x)))
                (deferred:nextc it
                  (lambda (x)
                    (princ "x=>")(princ x)(princ "\n")
                    (setq ukmc-selected-data x)))
                (deferred:nextc it
                  (lambda () (cc:semaphore-acquire ukmcEvtSem)))
                (deferred:nextc it
                  (lambda ()
                    (if ukmc-selected-data
                        (message "selected")
                      (message "timeout"))
                    (if ukmc-selected-data
                        (process-send-string
                           (process-name ukmc-client-process)
                           (ukmc-req-format
                            "OnChoiceSelect"
                            (list 0 ukmc-selected-data)))
                      (process-send-string
                       (process-name ukmc-client-process)
                       (ukmc-req-format
                        "OnChoiceTimeout"
                        (list 0 ""))))))
                (deferred:nextc it
                  (lambda ()
                    (ukmc-wait-for-shiori-response)))
                (deferred:nextc it
                  (lambda ()
                    (ukmc-crawl-proc-buf)
                    (cc:dataflow-clear ukmc-on-choice-dataflow 'choice)
                    (setq ukmcCanPlay "1")
                    (cc:semaphore-release ukmcEvtSem)))
                )
              )
          (setq ukmcCanPlay "1")
          )
        (setq ukmc-decoration-list nil))
       ;; newline ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       ((string-match "\\\\n" (car ret))
        (insert "\n        "))
       ;; wait command ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       ((string-match "\\\\w\\([0-9]\\)" (car ret))
        (setq interval
              (* 50
                 (string-to-number
                  (substring (car ret) (match-beginning 1) (match-end 1))))))
       ((string-match "\\\\_q" (car ret))
        t)
       ;; scope change ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       ((string-match "\\\\h\\|\\\\0" (car ret))
        (setq interval ukmc-scope-change-interval)
        (ukmc-talk-set-and-show-talker 0))
       ((string-match "\\\\u\\|\\\\1" (car ret))
        (setq interval ukmc-scope-change-interval)
        (ukmc-talk-set-and-show-talker 1))
       ((string-match "\\\\p\\[\\([0-9]+\\)\\]" (car ret))
        (setq interval ukmc-scope-change-interval)
        (ukmc-talk-set-and-show-talker
         (string-to-number
          (substring (car ret) (match-beginning 1) (match-end 1)))))
       ((string-match "\\\\p\\([0-9]\\)" (car ret))
        (setq interval ukmc-scope-change-interval)
        (ukmc-talk-set-and-show-talker
         (string-to-number
          (substring (car ret) (match-beginning 1) (match-end 1)))))
       ;; surface ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       ((string-match "\\\\s\\([0-9]\\)" (car ret))
        (aset ukmc-surface-list
              ukmc-talk-scope
              (string-to-number
               (substring (car ret) (match-beginning 1) (match-end 1)))))
       ((string-match "\\\\s\\[\\([0-9]+\\)\\]" (car ret))
        (aset ukmc-surface-list
              ukmc-talk-scope
              (string-to-number
               (substring (car ret) (match-beginning 1) (match-end 1)))))
       ;; question ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       ((string-match "\\\\q\\[\\([^,]+\\),\\([^]]+\\)\\]" (car ret))
        (setq pos (point))
        (setq ukmcCanPlay "0")
        (insert (match-string 1 (car ret)))
        (push (list pos (point)
                    (match-string 2 (car ret)) ; qid
                    'ukmc-question-face)
              ukmc-decoration-list))
       )
      (if (window-live-p (get-buffer-window ukmc-baloon-buf))
          (with-selected-window (get-buffer-window ukmc-baloon-buf)
            (goto-char (point-max))
            (forward-line
             (+ (/ (* -1 (window-height (get-buffer-window ukmc-baloon-buf))) 2) 2))
            (recenter))
        )

      (if (string= (car ret) "")
          nil
        (deferred:nextc (deferred:wait interval) 'ukmc-talk-exec-func))

      ) ;; with-current-buffer
    ) ;; let
  )

;; ukmc-crawl-proc-buf ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-crawl-proc-buf ()
  (let ((valid-body nil))
    (while (if (ukmc-proc-to-rcv) (setq valid-body t))  )
    (if valid-body
        (with-current-buffer ukmc-baloon-buf
          (goto-char (point-max))
          (insert (concat (nth ukmc-talk-scope ukmc-talk-scope-list) ": "))
          (cc:dataflow-clear ukmc-on-choice-dataflow 'choice)
          (deferred:$
            (deferred:next 'ukmc-talk-exec-func ))))))

;; ukmc-proc-to-rcv ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-proc-to-rcv ()
  (let ((body))
    (with-current-buffer ukmc-proc-buf
      (goto-char ukmc-proc-buf-pos)
      (if (re-search-forward "^Value: \\(.*\\)$" (point-max) t 1)
          (progn
            (setq ukmc-proc-buf-pos (point))
            (setq body (buffer-substring-no-properties
                        (match-beginning 1)
                        (match-end       1)))
            (setq body (replace-regexp-in-string "\\\\n\\\\n" "\\\\n" body ))
            (unless (string-match "\\\\e[\r\n]+$" body)
              (setq body (concat body "\\e")))
            (with-current-buffer ukmcRcvBuf
              (goto-char (point-max))
              (insert body)
              (insert "\n"))
            t)
        nil
        )
      )
    )
  )

;; ukmc-scan-command ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-scan-command ()
  (let ((start 1)(end 1)(talk "")(command ""))
    (set-buffer ukmcRcvBuf)
    (goto-char (point-min))
    (if
        (re-search-forward
         "\\\\_q\\|\\\\[swp][0-9]\\|\\(\\\\[a-z!]\\(\\[[^]]+\\]\\)\\{0,1\\}\\)\\|\\\\[0145]"
         (point-max) t 1)
        (progn
          (setq end      (point))
          (setq start    (match-beginning 0))
          (setq command  (buffer-substring-no-properties start       end  ))
          (setq talk     (buffer-substring-no-properties (point-min) start))
          )
      )
    (if (string= command "\\e")
        (kill-whole-line)
      (delete-region (point-min) end))
    (list command talk) ;; return val
    )
  )

;; ukmc-req-format ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-req-format (id &optional refs charset)
  (let ((request "GET SHIORI/3.0\n")
        (refnum  nil)
        (refbody nil))
    (setq request (concat request "ID: " id "\n"))
    (while (and (setq refnum (pop refs))
                (setq refbody (pop refs)))
      (setq request (concat request (format "Reference%d: %s\n"
                                            refnum refbody))))
    (if charset
        (setq request (concat request "Charset: " charset "\n"))
      request)
    (concat request "\n")))


;; on sec loop ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-onsec-loop ()
  (interactive)
  (deferred:$
    (deferred:nextc (cc:semaphore-acquire ukmcEvtSem)
      (lambda ()
        (process-send-string
         (process-name ukmc-client-process)
         (ukmc-req-format
          "OnSecondChange"
          (list 0 "0"         ;; system up(hour)
                1 "0"         ;; cut off
                2 "0"         ;; over lap
                3 ukmcCanPlay
                4 "0")))      ;; idle time(sec)
        ))
    (deferred:nextc it 'ukmc-wait-for-shiori-response)
    (deferred:nextc it 'ukmc-crawl-proc-buf)
    (deferred:nextc it
      (lambda () (cc:semaphore-release ukmcEvtSem)))
    (deferred:nextc it
      (lambda ()
        (unless ukmc-close-flag
          (deferred:nextc (deferred:wait 1000) 'ukmc-onsec-loop)
          nil)))
    )
  )

;; SetEvtBuf ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-put-evt-buf (id ref canplay)
  (with-current-buffer ukmcEvtBuf
    (cc:semaphore-acquire ukmcEvtSem)
    (goto-char (point-max))
    (insert (ukmc-req-format
             id
             ref))
    (setq ukmcCanPlay canplay)
    (cc:semaphore-release ukmcEvtSem)
    ) ; with-current-buffer
  )

;; ukmc-click-text ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-click-text ()
  (interactive)
  (let ((qid (get-text-property (point) 'qid)))
    (if (and ukmc-on-choice-dataflow qid)
        (cc:dataflow-set ukmc-on-choice-dataflow 'choice qid))))

;; crawl event buffer ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-crawl-event-buffer ()
  (interactive)
  (let ((req-begin 0)
        (req-end   0)
        (req-body  nil))
    (with-current-buffer ukmcEvtBuf
      (goto-char (point-min))
      (setq req-begin (search-forward "GET SHIORI/3.0" nil t 1)
            req-end   (search-forward "GET SHIORI/3.0" nil t 1))
      (unless req-end (setq req-end (point-max)))
      (if req-begin
          (progn
            (goto-char req-begin)
            (beginning-of-line)
            (setq req-begin (point))

            (goto-char req-end)
            (beginning-of-line)
            (setq req-end (point))

            (setq req-body
                  (buffer-substring-no-properties req-begin req-end))
            (process-send-string (process-name ukmc-client-process)
                                 req-body)
            (delete-region req-begin req-end)
            t
            )
        nil
        )
      )
    )
  )

;; ukmc-make-surface-collisions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-make-surface-collisions ()
  (setq ukmcSurfacesBuf
        (find-file-noselect (concat ukmc-ghost-path
                                    "shell\\master\\surfaces.txt")))
  (with-current-buffer ukmcSurfacesBuf
    (setq buffer-read-only t))
  (setq ukmc-surface-collision-hash (make-hash-table))
  (with-current-buffer (get-buffer "surfaces.txt")
    (message "surfaces.txt is opened...")
    (goto-char (point-min))
    (let ((start            (point-min))
          (end              (point-min))
          (surface-nums     nil)
          (collision        nil)
          (collision-num    nil)
          (collision-id     nil)
          (startx           nil)
          (starty           nil)
          (ret              nil)
          (buf              nil))
      (while (re-search-forward
              "surface\\([0-9,]+\\)[\r\n ]*{[^}]+}"
              (point-max) t 1)
        (message "searching surfaces...")
        (goto-char (match-beginning 0))
        (setq end (match-end 0))
        (setq surface-nums
              (mapcar 'string-to-number
                      (split-string (match-string 1) " *, *")))
        (mapcar
         (lambda (x)
           (message "surface-num:%d" x)
           (unless (gethash x ukmc-surface-collision-hash)
             (push (list 0 0 0 "UNDEF")
                   (gethash x ukmc-surface-collision-hash))))
         surface-nums)
        (while (re-search-forward
                (concat
                 "collision\\([0-9]+\\),"
                 "\\([0-9]+\\),\\([0-9]+\\),"
                 "\\([0-9]+\\),\\([0-9]+\\),"
                 "\\(.*\\)$")
                end t 1)
          (mapcar
           (lambda (x)
             (push
              (list
               (string-to-number (match-string 1))
               (string-to-number (match-string 2))
               (string-to-number (match-string 3))
               ;(string-to-number (match-string 4))
               ;(string-to-number (match-string 5))
               (buffer-substring-no-properties
                (match-beginning 6)(match-end 6)))
              (gethash x ukmc-surface-collision-hash)))
           surface-nums)

          )
        (mapcar
         (lambda (x)
           (puthash
            x
            (reverse (gethash x ukmc-surface-collision-hash))
            ukmc-surface-collision-hash ))
         surface-nums)
        (goto-char end))))
  (kill-buffer ukmcSurfacesBuf)
  )

;; ukmc-select-collision ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ukmc-select-collision()
  (interactive)
  (let ((scope-id)
        (collision-id)
        (sc-hash))
    (setq scope-id
          (completing-read
           "Scope: "
           (let ((i -1))
             (mapcar (lambda (x) (setq i (+ i 1)) (format "%02d:%s" i x))
                     ukmc-talk-scope-list))))
    (string-match "^\\([0-9]+\\):" scope-id)
    (setq scope-id
          (string-to-number
           (substring scope-id (match-beginning 1) (match-end 1))))
    (setq sc-hash
          (gethash
           (aref ukmc-surface-list scope-id)
           ukmc-surface-collision-hash))
    (setq collision-id
          (completing-read
           "Collision: "
           (let ((i -1))
             (mapcar (lambda (x) (setq i (+ i 1)) (format "%02d:%s" i (nth 3 x)))
                     sc-hash))))
    (string-match "^\\([0-9]+\\):" collision-id)
    (setq collision-id
          (string-to-number
           (substring collision-id (match-beginning 1) (match-end 1))))
    (list (nth 1 (nth collision-id sc-hash))
          (nth 2 (nth collision-id sc-hash))
          scope-id
          (nth 3 (nth collision-id sc-hash))
          )))
(defun ukmc-on-mouse-double-click ()
  (interactive)
  (let ((collision-pos (ukmc-select-collision)))
    (cc:semaphore-acquire ukmcEvtSem)
    (setq ukmcCanPlay "0")
    (process-send-string
     (process-name ukmc-client-process)
     (ukmc-req-format
      "OnMouseDoubleClick"
      (list 0 (format "%d" (nth 0 collision-pos)) ;; x
            1 (format "%d" (nth 1 collision-pos)) ;; y
            2 "0"         ;; always 0
            3 (format "%d" (nth 2 collision-pos))
            4 (nth 3 collision-pos)
            5 "0"         ;; 0:left click, 1:right click
            )))
    (deferred:$
      (deferred:next 'ukmc-wait-for-shiori-response)
      (deferred:nextc it 'ukmc-crawl-proc-buf)
      (deferred:nextc it
        (lambda ()
          (cc:semaphore-release ukmcEvtSem))))
    )
  )

(defun ukmc-on-mouse-wheel ()
  (interactive)
  (let ((collision-pos (ukmc-select-collision)))
    (cc:semaphore-acquire ukmcEvtSem)
    (setq ukmcCanPlay "0")
    (loop for i from 0 to 4 do
          (process-send-string
           (process-name ukmc-client-process)
           (ukmc-req-format
            "OnMouseWheel"
            (list 0 (format "%d" (nth 0 collision-pos)) ;; x
                  1 (format "%d" (nth 1 collision-pos)) ;; y
                  2 "32"         ;; direction and wheel amount
                  3 (format "%d" (nth 2 collision-pos))
                  4 (nth 3 collision-pos)
                  5 "0"         ;; 0:left click, 1:right click
                  ))))
    (deferred:$
      (deferred:next 'ukmc-wait-for-shiori-response)
      (deferred:nextc it 'ukmc-crawl-proc-buf)
      (deferred:nextc it
        (lambda ()
          (cc:semaphore-release ukmcEvtSem))))
    )
  )
