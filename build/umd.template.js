module.exports = {

  top: `
// see webpack's umd output.
(function (root, factory) {

  if (typeof exports === 'object' && typeof module === 'object')
		module.exports = factory()

	else if (typeof define === 'function' && define.amd)
		define([], factory)

	else if (typeof exports === 'object')
		exports.eventa = factory()

	else
		root.eventa = factory()

}(this, function () {
`,

  bottom: '}));\n',

}
