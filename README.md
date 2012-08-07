Dart Web Components
===================

Dart Web Components let you build web apps as if you had a browser from the
future. You can use the cool new web technologies like [Web Components][wc],
[Model Driven Views][mdv] and [Dart][d] today. Build apps easily using HTML as
your template language, express your application's components in HTML, and
synchronize your data automatically between Dart and your components.

We believe that:

- Web Components are on their way, we should start using them now.
- Cool new features should be made available to [modern browsers][mb] that
  haven't yet implemented them.
- Write/Reload is just as important as write/compile/minimize/ship.
- Working in open source is the way to go.
- Developers from all backgrounds should be building awesome modern web apps.

This library is under construction. More coming soon!


Running Tests
-------------

Dependencies are installed using the [Pub Package Manager][pub].

    pub install
    tests/run.sh                   # command line tests
    dumprendertree tests/run.html  # browser tests

You can run `tests/run.html` from [Dartium][] with
`--allow-file-access-from-files` or from a Dart enabled [DumpRenderTree][],
which can be downloaded prebuilt for [Ubuntu Lucid][drtlucid],
[Windows][drtwin], or [Mac][drtmac]. You can also build these from the
[Dartium and DRT sources][drtsrc].


[wc]: http://dvcs.w3.org/hg/webcomponents/raw-file/tip/explainer/index.html
[mdv]: http://code.google.com/p/mdv/
[d]: http://www.dartlang.org
[mb]: http://www.dartlang.org/support/faq.html#what-browsers-supported
[pub]: http://www.dartlang.org/docs/pub-package-manager/
[Dartium]: http://www.dartlang.org/dartium/index.html
[drtlucid]: http://gsdview.appspot.com/dartium-archive/continuous/drt-lucid64.zip
[drtmac]: http://gsdview.appspot.com/dartium-archive/continuous/drt-mac.zip
[drtwin]: http://gsdview.appspot.com/dartium-archive/continuous/drt-win.zip
[drtsrc]: http://code.google.com/p/dart/wiki/BuildingDartium
