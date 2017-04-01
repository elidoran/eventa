assert = require 'assert'
{EventEmitter} = require 'events'
buildEventa = require '../../lib/index.coffee'

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
    assert.strictEqual eventa._listeners[0][0].fn, fn, 'should be the same function'


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
    assert.strictEqual eventa._listeners?[0]?.length, 1, 'should be there'
    handle.remove()
    assert.strictEqual eventa._listeners[0].length, 1, 'should still have the spot'
    assert.strictEqual eventa._listeners[0][0], null, 'should be null'
    eventa.emit 'removing', 'blah'
    assert.equal eventa._listeners[0].length, 0, 'should be gone after emit'
    assert.equal listenerWasCalled, false, 'should not have called the listener'


  it 'should have a once() listener until it is called once', ->
    eventa = buildEventa()
    listenerWasCalled = false
    fn = -> listenerWasCalled = true
    handle = eventa.on 'removing', fn, null, 1
    assert.strictEqual eventa._listeners[0].length, 1, 'should have the spot'
    eventa.emit 'removing', 'blah'
    assert.equal eventa._listeners[0].length, 0, 'should be gone after emit'
    assert.equal listenerWasCalled, true, 'should have called the listener'


  it 'should remove a once listener with remove() before it is called', ->
    eventa = buildEventa()
    handle = null
    listenerWasCalled = false
    fn = -> listenerWasCalled = true
    handle = eventa.on 'removing', fn, null, 1
    assert.strictEqual eventa._listeners?[0]?.length, 1, 'should be there'
    handle.remove()
    assert.strictEqual eventa._listeners[0].length, 1, 'should still have the spot'
    assert.strictEqual eventa._listeners[0][0], null, 'should be null'
    eventa.emit 'removing', 'blah'
    assert.equal eventa._listeners[0].length, 0, 'should be gone after emit'
    assert.equal listenerWasCalled, false, 'should NOT have called the listener'


  it 'should allow remove() repeatedly', ->
    eventa = buildEventa()
    handle = eventa.on 'remove', ->
    handle.remove()
    handle.remove()
    handle.remove()
    eventa.emit 'remove', 'blah'
    assert.equal eventa._listeners[0].length, 0, 'should be gone after emit'
    handle.remove()
    handle.remove()
    handle.remove()


  it 'should remove a listener based on count', ->
    eventa = buildEventa()
    count = 0
    eventa.on 'count', (-> count++), null, 3
    assert.equal eventa._listeners[0].length, 1
    assert.equal count, 0

    eventa.emit 'count', 'blah'
    assert.equal count, 1
    assert.equal eventa._listeners[0].length, 1

    eventa.emit 'count', 'blah'
    assert.equal count, 2
    assert.equal eventa._listeners[0].length, 1

    eventa.emit 'count', 'blah'
    assert.equal count, 3
    assert.equal eventa._listeners[0].length, 0

    eventa.emit 'count', 'blah'
    assert.equal count, 3
    assert.equal eventa._listeners[0].length, 0


  it 'will emit start on start()', ->

    eventa = buildEventa()
    called = false
    eventa.on 'start', -> called = true
    eventa.start()
    assert.equal called, true, 'should have called start listener'


  it 'will try to require strings for load()', ->

    eventa = buildEventa()
    {resolve} = require 'path'
    path = resolve __dirname, '..', 'helpers', 'placeholder.js'
    eventa.load path
    placeholder = require path
    assert.equal placeholder.counter, 1, 'it should be called by load()'
    placeholder()
    assert.equal placeholder.counter, 2, 'it should be called by both load() and us'


  it 'will provide builder options from load() when they are provided', ->

    eventa = buildEventa()
    eventa.load fn: ->
    options = some:'options'
    optionsArg = null
    eventa.load options:options, fn: (eventa, theOptions) -> optionsArg = theOptions
    assert.strictEqual optionsArg, options


  it 'will report an error for an invalid object argument to load()', ->
    eventa = buildEventa()
    eventa.load {no:'good'}


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
