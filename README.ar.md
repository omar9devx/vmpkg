# VMPKG 🐧 — مدير حزم مستقل يعمل في فضاء المستخدم (User-Space)

**VMPKG** هو مدير حزم مستقل بالكامل (Self‑Contained Package Manager) مخصص لنظام لينكس،  
ويعمل حصريًا داخل مساحة المستخدم **بدون الحاجة إلى أي مدير حزم من النظام** مثل:

- apt  
- pacman  
- dnf / yum  
- zypper  
- apk  
- xbps  
- emerge  

لا يستخدم أيًا منها، ولا يتفاعل معها، ولا يستدعيها.  
بل يدير VMPKG سجله (Registry) ومساحته ومجلداته بنفسه داخل `~/.vmpkg`.

إذا كان لديك **Linux + Bash + curl/wget + tar (و unzip اختياري)** — فسوف يعمل VMPKG فورًا.

---

<p align="center">
  <a href="https://github.com/omar9devx/vmpkg/actions/workflows/ci.yml">
    <img src="https://github.com/omar9devx/vmpkg/actions/workflows/ci.yml/badge.svg" alt="CI">
  </a>
  <a href="https://github.com/omar9devx/vmpkg">
    <img src="https://img.shields.io/badge/version-1.3.0-blue.svg" alt="Version: 1.3.0">
  </a>
  <a href="https://github.com/omar9devx/vmpkg">
    <img src="https://img.shields.io/badge/platform-linux-333333?logo=linux&logoColor=ffffff" alt="Platform: Linux">
  </a>
  <a href="https://github.com/omar9devx/vmpkg">
    <img src="https://img.shields.io/badge/shell-bash-4EAA25?logo=gnu-bash&logoColor=ffffff" alt="Shell: Bash">
  </a>
  <a href="https://github.com/omar9devx/vmpkg/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-GPL-blue.svg" alt="License: MIT">
  </a>
  <a href="https://github.com/omar9devx/vmpkg">
    <img src="https://img.shields.io/badge/type-self--contained%20pkg%20manager-ff6f00" alt="Self-contained package manager">
  </a>
</p>

---

## 🧩 مميزات VMPKG

- يعمل بالكامل في مستخدمك الشخصي (User‑Space)  
- لا يحتاج إلى صلاحيات root إطلاقاً
- لا يتعامل مع أي مدير حزم في النظام  
- يعمل على *جميع توزيعات لينكس*  
- مستودع سجلات بسيط وسريع:  
  `name|version|url|description|[sha256]`  
- التحقق التلقائي من بصمة الملفات **SHA256** قبل التثبيت لضمان الأمان والنزاهة
- فحص وتحديث تلقائي للإصدارات الأحدث عبر أمر `vmpkg upgrade`
- يدعم أرشيفات:
  - `.tar.gz` / `.tgz`
  - `.tar.xz`
  - `.tar.bz2`
  - `.tar`
  - `.zip`
- كشف ذكي لنوع الأرشيف عبر `file` والامتدادات
- يثبّت الحزم داخل:  
  `~/.vmpkg/pkgs/<name>-<version>`  
- يربط الملفات التنفيذية داخل:
  `~/.local/bin`  
- آمن + يعتمد على Bash فقط  
- واجهة أوامر جميلة وواضحة مع ألوان  
- بيئة اختبارات مؤتمتة متكاملة وCI عبر GitHub Actions
- يحتوي أدوات مساعدة للنظام (system helpers)

---

## 🐧 التوافق

يعمل VMPKG على:

- Debian / Ubuntu / Mint / PopOS / Kali  
- Arch / Manjaro / EndeavourOS  
- Fedora / RHEL / CentOS  
- openSUSE  
- Alpine  
- Void  
- Gentoo  
- WSL  
- Docker Containers  
- VPS / VM  
- أي نظام لينكس حديث يدعم Bash

> **VMPKG لا يعد بديلاً لمدير الحزم الخاص بتوزيعتك.**  
> هو مدير حزم مستقل لمشاريعك وأدواتك الخاصة.

---

## 🧱 البنية المعمارية (Architecture)

تدفق العمل داخل VMPKG:

```
              ┌────────────────────────┐
              │   ملف السجل (Registry) │
              │ name|ver|url|desc      │
              └─────────┬──────────────┘
                        │
            vmpkg install <name>
                        │
                        ▼
            ┌───────────────────────┐
            │ تنزيل الأرشيف        │
            │ إلى ~/.vmpkg/cache    │
            └─────────┬─────────────┘
                      │
                      ▼
            ┌───────────────────────┐
            │ فك الأرشيف إلى        │
            │ ~/.vmpkg/pkgs/<pkg>    │
            └─────────┬─────────────┘
                      │
                      ▼
            ┌───────────────────────┐
            │ البحث عن bin/         │
            │ وإنشاء روابط (symlink)│
            │ في ~/.local/bin        │
            └─────────┬─────────────┘
                      │
                      ▼
            ┌───────────────────────┐
            │ الأداة تصبح متاحة     │
            │ في الـ PATH            │
            └───────────────────────┘
```

---

## 📦 نموذج الحزم داخل VMPKG

ملف السجل يكون بالشكل التالي:

```
name|version|url|description|[sha256]
```

مثال:

```
rg|14.1.0|https://example.com/ripgrep-14.1.0-x86_64.tar.gz|Fast search tool|d68ffad399d25514f76ba202cfbe9c4b7b25055b46e311394a5303c7343e8ea2
lazygit|0.44.0|https://example.com/lazygit-x86_64.tar.gz|Terminal UI for git
bat|0.24.0|https://example.com/bat-0.24.0.tar.gz|cat clone with syntax highlighting
```

> **ملاحظة:** عند تمرير قيمة `sha256`، يقوم `vmpkg` بالتحقق من صحة وبصمة ملف الأرشيف قبل فك ضغطه لحماية نظامك.

تركيب الأرشيف المتوقع:

```
mytool/
  bin/
    mytool
  lib/
  share/
```

---

## 🏗 التثبيت

### تثبيت بمستوى المستخدم (بدون root أو sudo — موصى به):

```bash
curl -fsSL https://raw.githubusercontent.com/omar9devx/vmpkg/main/installscript.sh | bash
```
> سيتم تثبيت الأداة في `~/.local/bin/vmpkg`. تأكد من وجود `~/.local/bin` في مسار `$PATH`.

### تثبيت للنظام بالكامل (يتطلب sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/omar9devx/vmpkg/main/installscript.sh | sudo bash
```
> سيتم تثبيت الأداة في `/usr/local/bin/vmpkg`.

---

## 🛠 التحديث والصيانة

```bash
curl -fsSL https://raw.githubusercontent.com/omar9devx/vmpkg/main/updatescript.sh | bash
```

يوفر:

- تحديث VMPKG  
- إصلاح الملفات  
- إعادة التثبيت  
- حذف كامل  
- حذف مع النسخ الاحتياطي  

---

## 🚀 الأوامر الأساسية

```bash
vmpkg init                  # تهيئة المجلدات الأساسية
vmpkg register …            # تسجيل حزمة في السجل (مع دعم sha256)
vmpkg install <name>        # تثبيت حزمة
vmpkg reinstall <name>      # إعادة التثبيت
vmpkg upgrade [name]        # فحص وترقية الحزم إلى إصدار أحدث
vmpkg remove <name>         # إزالة حزمة
vmpkg list                  # عرض الحزم المثبتة
vmpkg search <pattern>      # البحث في السجل
vmpkg show <name>           # عرض تفاصيل حزمة
vmpkg clean                 # تنظيف الكاش
vmpkg doctor                # فحص البيئة والتحذيرات
```

---

## 🔥 أمثلة واقعية على التسجيل والتثبيت

### 1 — Neovim

```bash
vmpkg register neovim 0.10.0 "https://example.com/nvim-linux.tar.gz" "Modern vim editor"

vmpkg install neovim
```

### 2 — ripgrep

```bash
vmpkg register rg 14.1.0 "https://example.com/ripgrep-14.1.0.tar.gz" "Fast grep alternative"

vmpkg install rg
```

### 3 — LazyGit

```bash
vmpkg register lazygit 0.44.0 "https://example.com/lazygit-0.44.0.tar.gz" "Simple terminal UI for git"

vmpkg install lazygit
```

---

## 🧠 الأسئلة الشائعة (FAQ)

### ❓ هل يستبدل VMPKG مدير الحزم في النظام؟

**لا.**  
VMPKG مستقل تمامًا ولا يلمس حزم النظام.

### ❓ هل يحتاج إلى sudo؟

**لا إطلاقًا.**  
كل شيء يتم داخل نطاق المستخدم.  
فقط سكربت التثبيت قد يستخدم sudo عند وضع ملف في `/usr/local/bin`.

### ❓ هل يعمل فوق apt أو pacman؟

**لا.**  
لا يستخدمهم، لا يتفاعل معهم، ولا يعتمد عليهم.

### ❓ أين يتم تخزين الحزم؟

في:

```
~/.vmpkg/registry
~/.vmpkg/pkgs/
~/.vmpkg/cache/
~/.vmpkg/db/
~/.local/bin
```

### ❓ هل يمكن استخدامه داخل Docker أو WSL؟

نعم، وفعّال جدًا لأنه:

- لا يحتاج إلى root  
- يعتمد على أدوات بسيطة  
- لا يغيّر النظام الأساسي  

---

## 📌 خلاصة

- VMPKG مدير حزم مستقل 100%  
- يعمل على جميع توزيعات لينكس  
- لا يحتاج إلى sudo ولا يعتمد على أي مدير حزم  
- يعتمد فقط على أرشيفات خارجية تقوم بتسجيلها في السجل  
- مناسب جدًا للبيئات المتعددة، وWSL، وDocker، والمطورين، و dotfiles  

