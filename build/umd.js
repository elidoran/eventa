// used to load our template and write our results.
const {readFileSync, writeFile} = require('fs')

// used to build paths from our `__dirname`,
// and show a relative path for created files.
const {join, relative} = require('path')

// join these parts here for brevity later.
const libDir = join(__dirname, '..', 'lib')

// get the two parts we'll wrap our code with for UMD
const parts = require('./umd.template.js')

// read our main file as a string to use in the template.
const string = readFileSync(join(libDir, 'index.js'), 'utf8')

// create a new MagicString instance to make changes and generate a map.
const magic = new (require('magic-string'))(string)

// add the top/bottom in
magic.prepend(parts.top)
magic.append(parts.bottom)

// make it export the function by returning it.
// we'll replace this code with a return call.
const find = 'module.exports = function'

// find the code we want to replace.
const start = string.indexOf(find)

// overwrite the code with our return statement.
magic.overwrite(start, start + find.length, 'return function')

// generate a map.
const map = magic.generateMap({
  source: 'index.js',
  file: 'umd.js.map',
  includeContent: true
})

// get changed string from magic and append the source URL
const code = magic.toString() + '\n//# sourceMappingURL=umd.js.map\n'

// use to write both the 'umd.js' and 'umd.js.map' files.
function write(file, content) {
  return writeFile(file, content, 'utf8', function(error, result) {
    if (error) {
      console.error('Failed to write:', file, error)
    } else {
      console.log('created', relative('.', file))
    }
  })
}

write(join(libDir, 'umd.js'), code)

write(join(libDir, 'umd.js.map'), map)
