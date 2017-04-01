# get the two parts we'll wrap our code with for UMD
parts = require './umd.template'

{readFileSync, writeFile} = require 'fs'

string = readFileSync 'lib/index.js', 'utf8'

# create a new MagicString instance to make changes with
magic = new (require 'magic-string') string

# add the top/bottom in
magic.prepend parts.top
magic.append parts.bottom

# make it export the function by returning it.
find = 'module.exports = function'
start = string.indexOf find
magic.overwrite start, start + find.length, 'return function'

map = magic.generateMap
  source: 'index.js'
  file  : 'umd.js.map'
  includeContent: true

code = magic.toString() + '\n//# sourceMappingURL=umd.js.map\n'

write = (file, content) ->
  writeFile file, content, 'utf8', (error, result) ->
    if error? then console.error 'Failed to write:', file, error
    else console.log 'created',file

write 'lib/umd.js', code
write 'lib/umd.js.map', map
