0.5.0 - Released 2019/04/30

1. switch from CS to JS for main file and UMD generator script/template.
2. update deps
3. swap scripts using CS for those using JS
4. swap coffeelint for eslint
5. now we can do coverage via Travis CI
6. drop node 4, add node 8-12 (evens)
7. change main file to use ES6 `const` and `let`
8. add 2019 to LICENSE
9. stop ignoring all lib/*.js and only ignore umd/map files
10. add one new test for 100% code coverage
11. remove defunct gemnasium badge from README
12. update README examples to use const


0.4.0 - Released 2017/04/05

1. added `waitFor()`
2. updated README about `waitFor()`
3. reimplement `load()` for cleaner API with options argument
4. updated README for new `load()`
5. added more README documentation *outside* of the code blocks and split up some code blocks (still needs more work)


0.3.0 - Released 2017/04/02

1. added ability to provide `__dirname` to resolve local modules in `load()`
2. updated tests to fully test the above change and provide full code coverage
3. updated README a bit to show providing `__dirname`


0.2.0 - Released 2017/04/01

1. added a little extra babble to the README's description at the top.
2. rewrote internal storage to use a single array
3. moved listener array cleanup into its own function
4. added `cleanup()` to compact stored info (get rid of empties)
5. added tests for the cleaning stuff


0.1.1 - Released 2017/04/01

1. fixed README header links
2. fixed CHANGES.md

0.1.0 - Released 2017/04/01

1. initial working version with tests, 100% coverage, Travis CI, unpkg
