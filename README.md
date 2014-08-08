SeeSS
=====

SeeSS Chrome extension helps you identify unintended visual changes by visualizing CSS change impact.

Current status: WIP. See design notes in [Hackpad](https://seess.hackpad.com/SeeSS-Open-Source-Project-bFQvnONEMEE).

Installing SeeSS
----------------

Currently WIP. No prebuilt extension is provided now.



Developing
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
[Cr Reloader Backend](https://chrome.google.com/webstore/detail/cr-reloader-backend/djacajifmnoecnnnpcgiilgnmobgnimn). Before developing, please open Cr Reloader from your [Chrome App Launcher](https://chrome.google.com/webstore/launcher).


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