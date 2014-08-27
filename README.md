SeeSS
=====

[![Build Status](https://travis-ci.org/MrOrz/SeeSS.svg?branch=master)](https://travis-ci.org/MrOrz/SeeSS)

Current status: WIP. See [design notes](https://seess.hackpad.com/SeeSS-Open-Source-Project-bFQvnONEMEE) and [current system](https://seess.hackpad.com/SeeSS-Open-Source-Project-Structure-xTK0bgHyFoj) structure in Hackpad.

When we write program, the code editor or IDE provides lots of hints like underlines and highlights that points out our mistakes. However, what do we have when we are tweaking complex graphical user interfaces, for example, a website?

Now, we have SeeSS.

*TODO A demo screenshot/gif/video here*

SeeSS is a Chrome extension that helps you identify unintended visual changes by visualizing CSS change impact. It tells you what parts of website has visually changed everytime you hit save in the code editor, satisfying your desire to oversee the impact of every line you've edited. It is the missing tool in your front-end development flow, sitting right between your editor and the preview browser.

*TODO A image of where SeeSS belongs in csste.st flow*


Installation
----------------

Currently WIP. No prebuilt extension is provided now.



Development
----------

After cloning the repository, do the following in the terminal.

```
$ npm install -g gulp LiveScript
$ npm install
$ bower install
$ gulp
```

The unpacked Google Chrome Extension will then be compiled to `build/`.

We use [`cr-reloader`](https://github.com/victorhsieh/cr-reloader/) to reload the extension on file save. Please install both [Cr Reloader](https://chrome.google.com/webstore/detail/cr-reloader/gmmimkfknamjlkfclhbjojlbmiijcmgm) and
[Cr Reloader Backend](https://chrome.google.com/webstore/detail/cr-reloader-backend/djacajifmnoecnnnpcgiilgnmobgnimn). Before developing, please open Cr Reloader from your [Chrome App Launcher](https://chrome.google.com/webstore/launcher). Also, don't forget to update `EXTENSION_ID` constant in `gulpfile.ls`.


Tests
-----

```
$ npm test
```

License
-------

The source code in `src/` and `build/` are MIT Licensed. Source code in `vendor/` are distributed as their original license.


Team
----

[NTU Mobile HCI Lab](http://www.ntumobile.org/)


Publication
-----------

This Google Chrome extension is an open-source re-write of the original version in the paper *[SeeSS: Seeing What I Broke -- Visualizing Change Impact of Cascading Style Sheets (CSS)](http://dl.acm.org/citation.cfm?id=2502006)* ([raw version before peer-review](https://dl.dropboxusercontent.com/u/3813488/seess-non-peer-reviewed.pdf)), which was published in ACM UIST 2013.