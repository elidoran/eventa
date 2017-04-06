assert = require 'assert'
{EventEmitter} = require 'events'
buildEventa = require '../../lib/index.coffee'

# helper to look into the eventa object
firstListeners = (eventa) -> eventa._info[0].listeners

describe 'test eventa', ->

  it 'will load array provided to builder', ->

    receivedEventa = null
    fn = (theEventa) -> receivedEventa = theEventa
    eventa = buildEventa [ fn ]
    assert.strictEqual receivedEventa, eventa, 'did not receive the eventa'


  it 'should add a listener via on()', ->
    eventa = buildEventa()
    fn = ->
    eventa.on 'test add', fn
    assert.strictEqual firstListeners(eventa)[0].fn, fn, 'should be the same function'


  it 'should allow emit for an event with zero listeners', ->
    eventa = buildEventa()
    eventa.emit 'empty', zero:'listeners'


  it 'should call an added listener via emit()', ->
    eventa = buildEventa()
    called = false
    testObject = test:true
    fn = (eventObject) -> called = eventObject
    eventa.on 'test emit', fn
    eventa.emit 'test emit', testObject
    assert.strictEqual called, testObject


  it 'should have a listener until remove() is called', ->
    eventa = buildEventa()
    handle = null
    listenerWasCalled = false
    fn = -> listenerWasCalled = true
    handle = eventa.on 'removing', fn
    assert.strictEqual firstListeners(eventa).length, 1, 'should be there'
    handle.remove()
    assert.strictEqual firstListeners(eventa).length, 1, 'should still have the spot'
    assert.strictEqual firstListeners(eventa)[0], null, 'should be null'
    eventa.emit 'removing', 'blah'
    assert.equal firstListeners(eventa).length, 0, 'should be gone after emit'
    assert.equal listenerWasCalled, false, 'should not have called the listener'


  it 'should have a once() listener until it is called once', ->
    eventa = buildEventa()
    listenerWasCalled = false
    fn = -> listenerWasCalled = true
    handle = eventa.once 'removing', fn
    assert.strictEqual firstListeners(eventa).length, 1, 'should have the spot'
    eventa.emit 'removing', 'blah'
    assert.equal firstListeners(eventa).length, 0, 'should be gone after emit'
    assert.equal listenerWasCalled, true, 'should have called the listener'


  it 'should remove a once listener with remove() before it is called', ->
    eventa = buildEventa()
    handle = null
    listenerWasCalled = false
    fn = -> listenerWasCalled = true
    handle = eventa.once 'removing', fn
    assert.strictEqual firstListeners(eventa).length, 1, 'should be there'
    handle.remove()
    assert.strictEqual firstListeners(eventa).length, 1, 'should still have the spot'
    assert.strictEqual firstListeners(eventa)[0], null, 'should be null'
    eventa.emit 'removing', 'blah'
    assert.equal firstListeners(eventa).length, 0, 'should be gone after emit'
    assert.equal listenerWasCalled, false, 'should NOT have called the listener'


  it 'should allow remove() repeatedly', ->
    eventa = buildEventa()
    handle = eventa.on 'remove', ->
    handle.remove()
    handle.remove()
    handle.remove()
    eventa.emit 'remove', 'blah'
    assert.equal firstListeners(eventa).length, 0, 'should be gone after emit'
    handle.remove()
    handle.remove()
    handle.remove()


  it 'should remove a listener based on count', ->
    eventa = buildEventa()
    count = 0
    eventa.on 'count', (-> count++), null, 3
    assert.equal firstListeners(eventa).length, 1
    assert.equal count, 0

    eventa.emit 'count', 'blah'
    assert.equal count, 1
    assert.equal firstListeners(eventa).length, 1

    eventa.emit 'count', 'blah'
    assert.equal count, 2
    assert.equal firstListeners(eventa).length, 1

    eventa.emit 'count', 'blah'
    assert.equal count, 3
    assert.equal firstListeners(eventa).length, 0

    eventa.emit 'count', 'blah'
    assert.equal count, 3
    assert.equal firstListeners(eventa).length, 0


  it 'will emit start on start()', ->

    eventa = buildEventa()
    called = false
    eventa.on 'start', -> called = true
    eventa.start()
    assert.equal called, true, 'should have called start listener'


  it 'will try to require strings for load()', ->

    eventa = buildEventa()
    {join, resolve} = require 'path'
    path1 = '../helpers/placeholder.js'
    path2 = './helper.js' # join '.', 'helper.js'

    # this is allll to create a fake package to require as a non-local module.
    fakePackage = 'blahblahblah'
    fakePath = resolve '../../node_modules', fakePackage
    require.cache[fakePath] =
      id: fakePath
      filename: fakePath
      loaded: true
      exports: (eventa) ->
    Module = require 'module'
    realResolve = Module._resolveFilename
    Module._resolveFilename = (request, parent) ->
      if request is fakePackage then fakePath
      else realResolve request, parent

    # finally, load all three.
    eventa.load [path1, path2, fakePackage], __dirname

    placeholder = require path1
    assert.equal placeholder.counter, 1, 'it should be called by load()'
    placeholder()
    assert.equal placeholder.counter, 2, 'it should be called by both load() and us'


  it 'will load() arrays inside arguments', ->

    eventa = buildEventa()
    called = false
    eventa.load [ [-> called = true] ]
    assert.equal called, true, 'it should be called by load()'


  it 'will provide options from load() when they are provided', ->

    eventa = buildEventa()
    eventa.load ->
    options = some:'options'
    optionsArg = null
    eventa.load ((eventa, theOptions) -> optionsArg = theOptions), options
    assert.strictEqual optionsArg, options


  it 'will use both options and __dirname for load()', ->

    eventa = buildEventa()
    eventa.load ->
    options = some:'options'
    eventa.load '../helpers/options.js', options, __dirname
    receivedOptions = require('../helpers/options.js').options
    assert.strictEqual receivedOptions, options


  it 'will report an error for an invalid argument to load()', ->
    eventa = buildEventa()
    eventa.load 12345


  it 'will forward emitted events to another emitter', ->

    eventa = buildEventa()
    emitter = new EventEmitter
    eventa.forward 'blah', emitter
    received = false
    emitter.on 'blah', -> received = true
    eventa.emit 'blah', blah:true
    assert.equal received, true


  it 'will forward emitted events to another emitter with different name', ->

    eventa = buildEventa()
    emitter = new EventEmitter
    eventa.forward 'blah', emitter, 'blah2'
    received = false
    emitter.on 'blah2', -> received = true
    eventa.emit 'blah', blah:true
    assert.equal received, true


  it 'will receive events emitted on another emitter', ->

    eventa = buildEventa()
    emitter = new EventEmitter
    eventa.watch emitter, 'blah'
    received = false
    eventa.on 'blah', -> received = true
    emitter.emit 'blah', blah:true
    assert.equal received, true


  it 'will receive events emitted on another emitter and re-emit with new name', ->

    eventa = buildEventa()
    emitter = new EventEmitter
    eventa.watch emitter, 'blah', null, 'blah2'
    received = false
    eventa.on 'blah2', -> received = true
    emitter.emit 'blah', blah:true
    assert.equal received, true


  it 'will stop the watched re-emitting on remove()', ->

    eventa = buildEventa()
    emitter = new EventEmitter
    handle = eventa.watch emitter, 'blah', null, 'blah2'
    received = 0
    eventa.on 'blah2', -> received++
    emitter.emit 'blah', blah:true
    handle.remove()
    emitter.emit 'blah', blah:true
    assert.equal received, 1, 'should still be 1 after a second emit cuz it was removed'


  it 'will be unable to remove listener from other emitter which doesnt have a remove', ->

    eventa = buildEventa()
    emitter =
      on: (event, listener) -> @listener = listener
      emit: (e, o) -> @listener o
    handle = eventa.watch emitter, 'blah', null, 'blah2'
    received = 0
    eventa.on 'blah2', -> received++
    emitter.emit 'blah', blah:true
    handle.remove()
    emitter.emit 'blah', blah:true
    assert.equal received, 2, 'should 2 cuz removal was impossible'


  it 'will receive events emitted on another emitter and create custom args array', ->

    eventa = buildEventa()
    emitter = new EventEmitter
    eventa.watch emitter, 'blah', (object) -> [object, 'blahblah']
    received = false
    eventa.on 'blah', -> received = true
    emitter.emit 'blah', blah:true
    assert.equal received, true


  it 'will receive events emitted on another emitter and create custom arg (non-array)', ->

    eventa = buildEventa()
    emitter = new EventEmitter
    eventa.watch emitter, 'blah', (object) -> object
    received = false
    eventa.on 'blah', -> received = true
    emitter.emit 'blah', blah:true
    assert.equal received, true


  it 'will watch to re-emit errors', ->

    eventa = buildEventa()
    emitter = new EventEmitter
    message = 'an error'
    eventa.watchError emitter, message
    received = false
    eventa.on 'error', (error) -> received = error
    emitError = error:true
    emitter.emit 'error', emitError
    assert.deepEqual received,
      error: message
      Error: emitError


  it 'will watch to re-emit first error until remove()', ->

    eventa = buildEventa()
    emitter = new EventEmitter
    message = 'an error'
    handle = eventa.watchError emitter, message
    received = false
    eventa.on 'error', (e) -> received = e
    emitter.emit 'error', 'first error'
    assert.equal received.Error, 'first error', 'first emit receives first error'
    handle.remove()
    emitter.on 'error', -> # do nada. just have a listener so it doesn't freak out.
    emitter.emit 'error', 'second error'
    assert.equal received.Error, 'first error', 'remove() successful so unchanged'


  it 'will watch to re-emit errors when unable to remove()', ->

    eventa = buildEventa()
    emitter =
      on: (event, listener) -> @listener = listener
      emit: (e, o) -> @listener o
    message = 'an error'
    handle = eventa.watchError emitter, message
    received = false
    eventa.on 'error', (error) -> received = error
    emitter.emit 'error', 'first error'
    handle.remove()
    emitter.emit 'error', 'second error'
    assert.equal received.Error, 'second error', 'unable to remove() so it received the new one'


  it 'will provide a function which emits each arg as an event', ->

    eventa = buildEventa()
    acceptor = eventa.accept ['first', 'second']
    first = null
    eventa.on 'first', (v) -> first = v
    second = null
    eventa.on 'second', (v) -> second = v
    acceptor 'one', 'two'
    assert.equal first.object, 'one'
    assert.equal second.object, 'two'


  it 'will provide a function which emits each arg as an event', ->

    eventa = buildEventa()
    acceptor = eventa.accept ['first', 'second']
    first = null
    eventa.on 'first', (v) -> first = v
    second = null
    eventa.on 'second', (v) -> second = v
    acceptor 'one'
    assert.equal first.object, 'one'
    assert.equal second, null


  it 'will provide a function which emits each arg as an event', ->

    eventa = buildEventa()
    acceptor = eventa.accept ['error', 'result'], 'error msg'
    first = null
    second = null
    eventa.on 'error', (v) -> first = v
    eventa.on 'result', (v) -> second = v
    acceptor 'one', 'two'
    assert.equal first.error, 'error msg'
    assert.equal first.Error, 'one'
    assert.equal second.object, 'two'


  it 'will compact listener array after emit if nulls were found', ->

    eventa = buildEventa()
    handle = null
    fn1 = ->
    fn3 = ->
    eventa.on 'blah', fn1
    handle = eventa.on 'blah', ->
    eventa.on 'blah', fn3

    handle.remove()

    assert.equal eventa._info.length, 1, 'only one event'
    assert.equal eventa._info[0].listeners.length, 3, 'three listeners'
    assert.equal eventa._info[0].listeners[0].fn, fn1
    assert.equal eventa._info[0].listeners[1], null, 'second listener is nulled'
    assert.equal eventa._info[0].listeners[2].fn, fn3, 'third listener exists'

    eventa.emit 'blah', test:true

    assert.equal eventa._info.length, 1, 'only one event'
    assert.equal eventa._info[0].listeners.length, 2, 'now two listeners'
    assert.equal eventa._info[0].listeners[0].fn, fn1, 'first listener still exists'
    assert.equal eventa._info[0].listeners[1].fn, fn3, 'third listener is now second'



  it 'will compact the internal structure eliminating empty event info', ->

    eventa = buildEventa()
    handles = []
    handles.push eventa.on 'blah1', ->
    handles.push eventa.on 'blah1', ->
    handles.push eventa.on 'blah1', ->
    handles.push eventa.on 'blah2', ->
    handles.push eventa.on 'blah2', ->
    handles.push eventa.on 'blah2', ->
    handles.push eventa.on 'blah2', ->
    handles.push eventa.on 'blah3', ->
    handles.push eventa.on 'blah4', ->
    handles.push eventa.on 'blah4', ->
    handles.push eventa.on 'blah5', ->
    handles.push eventa.on 'blah5', ->
    handles.push eventa.on 'blah5', ->
    handles.push eventa.on 'blah5', ->
    handles.push eventa.on 'blah6', ->
    handles.push eventa.on 'blah6', ->

    assert.equal eventa._info.length, 6, 'should be 6 event infos in there'
    assert.equal eventa._info[0].listeners.length, 3, 'three blah1'
    assert.equal eventa._info[1].listeners.length, 4, 'four blah2'
    assert.equal eventa._info[2].listeners.length, 1, 'one blah3'
    assert.equal eventa._info[3].listeners.length, 2, 'two blah4'
    assert.equal eventa._info[4].listeners.length, 4, 'four blah5'
    assert.equal eventa._info[5].listeners.length, 2, 'two blah6'

    assert eventa._info[1].listeners[0], 'blah2 listeners exist'
    assert eventa._info[2].listeners[0], 'blah3 listeners exist'
    assert eventa._info[4].listeners[0], 'blah5 listeners exist'

    handle.remove() for handle in handles[3..7]   # blah2 and blah3
    handle.remove() for handle in handles[10..13] # blah5

    # still the same lengths. they're just null elements
    assert.equal eventa._info[0].listeners.length, 3, 'three blah1'
    assert.equal eventa._info[1].listeners.length, 4, 'four blah2'
    assert.equal eventa._info[2].listeners.length, 1, 'one blah3'
    assert.equal eventa._info[3].listeners.length, 2, 'two blah4'
    assert.equal eventa._info[4].listeners.length, 4, 'four blah5'
    assert.equal eventa._info[5].listeners.length, 2, 'two blah6'

    # now they're null
    assert.equal eventa._info[1].listeners[0], null, 'blah2 listeners nulled'
    assert.equal eventa._info[2].listeners[0], null, 'blah3 listeners nulled'
    assert.equal eventa._info[4].listeners[0], null, 'blah5 listeners nulled'

    eventa.cleanup()

    assert.equal eventa._info.length, 3, 'should be 3 event infos left in there'
    assert.equal eventa._info[0].listeners.length, 3, 'three blah1'
    assert.equal eventa._info[1].listeners.length, 2, 'two blah4'
    assert.equal eventa._info[2].listeners.length, 2, 'two blah6'



  it 'will waitFor() multiple events with all single args', ->

    eventa = buildEventa()
    empty = new Array 3
    called = false
    result = new Array 3
    eventa.waitFor [ 'a', 'b', 'c' ], (a, b, c) ->
      called = true
      result[0] = a
      result[1] = b
      result[2] = c

    assert.deepEqual result, empty, 'should be empty to start'
    assert.equal called, false, 'shouldnt be called right away'

    eventa.emit 'd', diff:'event'

    assert.equal called, false, 'shouldnt be called yet 1'
    assert.deepEqual result, empty, 'should still be empty after first diff event'

    eventa.emit 'b', '2'

    assert.equal called, false, 'shouldnt be called yet 2'
    assert.deepEqual result, empty, 'should have the b but not call yet'

    eventa.emit 'a', '1'

    assert.equal called, false, 'shouldnt be called yet 3'
    assert.deepEqual result, empty, 'should have the a as well, but not clal yet'

    eventa.emit 'e', diff:'event'

    assert.equal called, false, 'shouldnt be called yet 4'
    assert.deepEqual result, empty, 'should still be the same after second diff event'

    eventa.emit 'c', '3'

    assert.equal called, true, 'should be called'
    assert.deepEqual result, ['1', '2', '3']


  it 'will waitFor() multiple events with one providing multiple args', ->

    eventa = buildEventa()
    empty = new Array 3
    called = false
    result = new Array 3
    listener = (a, b, c) ->
      called = true
      result[0] = a
      result[1] = b
      result[2] = c

    eventa.waitFor [ 'a', 'b', 'c' ], listener, null, many:true

    assert.deepEqual result, empty, 'should be empty to start'
    assert.equal called, false, 'shouldnt be called right away'

    eventa.emit 'd', diff:'event'

    assert.equal called, false, 'shouldnt be called yet 1'
    assert.deepEqual result, empty, 'should still be empty after first diff event'

    eventa.emit 'b', '2', '22', 'two'

    assert.equal called, false, 'shouldnt be called yet 2'
    assert.deepEqual result, empty, 'should have the b but not call yet'

    eventa.emit 'a', '1'

    assert.equal called, false, 'shouldnt be called yet 3'
    assert.deepEqual result, empty, 'should have the a as well, but not clal yet'

    eventa.emit 'e', diff:'event'

    assert.equal called, false, 'shouldnt be called yet 4'
    assert.deepEqual result, empty, 'should still be the same after second diff event'

    eventa.emit 'c', '3'

    assert.equal called, true, 'should be called'
    assert.deepEqual result, ['1', ['2', '22', 'two'], '3']


  it 'will waitFor() multiple events and intermediate repeats overwrite', ->

    eventa = buildEventa()
    empty = new Array 3
    called = false
    result = new Array 3
    listener = (a, b, c) ->
      called = true
      result[0] = a
      result[1] = b
      result[2] = c

    eventa.waitFor [ 'a', 'b', 'c' ], listener

    assert.deepEqual result, empty, 'should be empty to start'
    assert.equal called, false, 'shouldnt be called right away'

    eventa.emit 'd', diff:'event'

    assert.equal called, false, 'shouldnt be called yet 1'
    assert.deepEqual result, empty, 'should still be empty after first diff event'

    eventa.emit 'b', '2', '22', 'two'
    # REPEAT OVERWRITES
    eventa.emit 'b', 'two'

    assert.equal called, false, 'shouldnt be called yet 2'
    assert.deepEqual result, empty, 'should have the b but not call yet'

    eventa.emit 'a', '1'

    assert.equal called, false, 'shouldnt be called yet 3'
    assert.deepEqual result, empty, 'should have the a as well, but not clal yet'

    eventa.emit 'e', diff:'event'

    assert.equal called, false, 'shouldnt be called yet 4'
    assert.deepEqual result, empty, 'should still be the same after second diff event'

    eventa.emit 'c', '3'

    assert.equal called, true, 'should be called'
    assert.deepEqual result, ['1', 'two', '3']


  it 'will waitFor() multiple events and reset for another round', ->

    eventa = buildEventa()
    empty = new Array 3
    called = false
    result = new Array 3
    listener = (a, b, c) ->
      called = true
      result[0] = a
      result[1] = b
      result[2] = c

    eventa.waitFor [ 'a', 'b', 'c' ], listener

    assert.deepEqual result, empty, 'should be empty to start'
    assert.equal called, false, 'shouldnt be called right away'

    eventa.emit 'd', diff:'event'

    assert.equal called, false, 'shouldnt be called yet 1'
    assert.deepEqual result, empty, 'should still be empty after first diff event'

    eventa.emit 'b', 'two'
    # NOTE: REPEAT OVERWRITES
    eventa.emit 'b', '2'

    assert.equal called, false, 'shouldnt be called yet 2'
    assert.deepEqual result, empty, 'should have the b but not call yet'

    eventa.emit 'a', '1'

    assert.equal called, false, 'shouldnt be called yet 3'
    assert.deepEqual result, empty, 'should have the a as well, but not clal yet'

    eventa.emit 'e', diff:'event'

    assert.equal called, false, 'shouldnt be called yet 4'
    assert.deepEqual result, empty, 'should still be the same after second diff event'

    eventa.emit 'c', '3'

    assert.equal called, true, 'should be called'
    assert.deepEqual result, ['1', '2', '3']

    # use different stuff for the second round
    eventa.emit 'd', diff:'event'
    eventa.emit 'b', 'bbb'
    eventa.emit 'a', 'aaa'
    eventa.emit 'e', diff:'event'
    eventa.emit 'c', 'ccc'

    assert.deepEqual result, [ 'aaa', 'bbb', 'ccc' ]
