# eventa
[![Build Status](https://travis-ci.org/elidoran/eventa.svg?branch=master)](https://travis-ci.org/elidoran/eventa)
[![npm version](https://badge.fury.io/js/eventa.svg)](http://badge.fury.io/js/eventa)
[![Coverage Status](https://coveralls.io/repos/github/elidoran/eventa/badge.svg?branch=master)](https://coveralls.io/github/elidoran/eventa?branch=master)

Simple advanced central event communicator.

An event emitter with extra methods to manage events flowing between multiple emitters.
It helps handle errors and emitting results for listeners to react to.


## Install

```sh
npm install eventa --save
```


## Usage


### Usage: Build Eventa

```javascript
// package returns a builder function
const buildEventa = require('eventa')

// build it plain:
const eventa = buildEventa()
```

Provide `load()` arguments to the builder as a convenience. It accepts all forms of arguments exactly like `load()`.


### Usage: load()

Load accepts three types of things:

1. **function** - it will call the function providing itself as the first argument.
2. **string** - it will attempt to `require()` the string. If the string starts with `'./'` or `'../'` then it will attempt to resolve it with the second argument to `load()`. So, when loading local modules either use `require.resolve()` on them first or specify `__dirname` as the second argument. It expects the `require()` result to provide a function which will be called as described above.
3. **array** - an array containing any of the above two types. When the array contains local module paths then provide `__dirname` as second argument, or, use `require.resolve()` on them.

Note, it's possible to include an array inside an array provided to `load()`. This allows packages and modules to provide more things to load. However, paths relative to the module must be resolved via `require.resolve()` unless they will resolve the same as the original `load()` caller, or, they are relative to the current working directory.


```javascript
// load a package:
eventa.load('some-package')
// with options:
eventa.load('some-package', {some:'options'})

// use an array to specify many at once:
eventa.load(['some-package', 'another-package'])
// with options:
eventa.load(['some-package', 'another-package'], {the:'options'})

// load a relative path to a module:
// NOTE: you must either provide __dirname or use require.resolve
eventa.load('./local', __dirname)
eventa.load(require.resolve('./local'))

// with options:
eventa.load('./local', {options:'second'}, __dirname)
eventa.load(require.resolve('./local'), {options:'second'})

// use an array to specify a mix of packages and local modules:
eventa.load(['some-package','./local'], __dirname)
// with options reused for each one:
eventa.load(['some-package','./local'], {options:'second'}, __dirname)
```


### Usage: Common Event Emitter

Eventa provides the common event emitter functions, with some extra abilities.

1. Provide a context for an event listener function. This allows a class instance method to be used as a listener by providing both its function and the class instance itself. This avoids the annoying `object.method.bind(object)` and the extra bind wrapper function. Instead, you can do: `eventa.on('event', object.method, object)`.
2. Specify the number of times a listener may be called before it is removed. This extends the `once()` ability to a count you specify. For example, five times: `eventa.on('event', someFn, null, 5)` (Note, the `null` is the context we're not providing).
3. The `on()` and `once()` functions return a "handle" object. It contains a `remove` function which will remove the listener from the **eventa** instance. This makes removing listeners much easier because it avoids requiring all the original arguments. It can be called inside the listener while an event emit is running, or, anytime.


```javascript
// the usual on(), once(), and emit()
eventa.on('someEvent', function() { /* do something */ })
eventa.once('someEvent', function() { /* do something */ })
eventa.emit('someEvent', 'blah1', {blah:'two'})

// on() and once() return an object with a `remove` function
// to remove the listener.
const handle = eventa.on('event name', function() {})

// then you can remove it at any time:
handle.remove()

// you can even do that while inside the listener:
const theHandle = eventa.on('name', function() { theHandle.remove() })

// instead of a once() function, you can specify the number of times
// a listener is allowed to run. (null is context)
eventa.on('one time', function(){}, null, 1)
eventa.on('counted 5 times', function(){}, null, 5)
// the usual once() is available as a convenience.
// it's the same as calling the 'one time' example above:
eventa.once('one time', function(){})

// event listener functions run without a context, usually.
// specify a context object as the third parameter.
// this helps use functions attached to an object,
// such as a class instance.
// this avoids doing:  thing.method.bind(thing)
// and the extra bind wrapper function call.
const thing = new Thing
eventa.on('e', thing.method, thing)
eventa.once('e', thing.method, thing)
```


### Usage: Advanced Event Controls

Eventa helps build an event-driven app with extra functions.

1. **start()** - convenience function which emits a `'start'` event. Its purpose is to encourage a focus of setting up event listeners at load including special `'start'` ones to get things going once it's all ready.
2. **load()** - used to load other packages and local modules into the Eventa. Its purpose is to help split up the event listener providers into separate modules and, allow packages to provide common event listeners.
3. **waitFor()** - An advanced `on()` which calls the specified listener when **all** the specified events have occurred. It gathers their arguments and provides those to the listener in the same order as the event names are provided. By default it expects each event emits a single argument. To accept multiple arguments provide `{many:true}` as the options arg.
4. **forward()** - Emit an Eventa event on another emitter. Optionally, with a different event name. The opposite of `watch()`. It has the opposite argument order to watch. Eventa forwards an event to another emitter, so, `eventa.forward('event', emitter, ...)`. A "handle" is returned with a `remove()` function to remove the forward.
5. **watch()** - Emit another emitter's event on the Eventa. Optionally, with a different event name. The opposite of `forward()`. It has the opposite argument order to forward. Eventa watches another emitter for an event, so, `eventa.watch(emitter, 'event', ...)`. A "handle" is returned with a `remove()` function to remove the watcher. The third argument accepts a function to call with the args from the event listener. It allows creating an array of arguments to provide to the watch's event listener. Essentially, changing the other emitter's event arguments into ones of your own.
6. **watchError()** - A special case of `watch()` for `'error'` events. Specify the emitter to watch and an error message to use. It expects the error will be emitted with a single error argument. It will emit on Eventa with a single argument as well. It will have an `error` property containing the error message specified to `watchError()` and, an `Error` property with the error object provided to the original listener.
7. **accept** - Provides a callback function which will emit each argument as an event using the name specified in the array. The order of the names is used to match them to the arguments. Use this to have it emit the usual error or result arguments with custom names. If the name `'error'` is used then it receives the same treatment as in `watchError()` to produce an object with both `'error'` and `'Error'` properties.


```javascript
// 1. start()
// simply emits a start event. It may develop into more later,
// for now, it's simple.
// add listeners to the 'start' event which will begin the parts of your
// app which instigate/initiate things, such as a server socket or timer.
eventa.start()

// 2. load()
// see the 'Usage: load()' section for a complete example set.

// 3. waitFor()
// Listens to all specified events.
// Stores the args provided by the events.
// When all events have occurred, call the provided listener with them all.
// The args will be in the same order as the event names provided.
// Default expects each event emits a single argument.
eventa.waitFor(['a', 'b', 'c'], function (a, b, c) {
  // now you have all the event results...
})

// If any event emits more than one argument, set `many` option:
eventa.waitFor(['a', 'b', 'c'], function (a, b, c) {
  // now you have all the event results...
  // if any of the events had multiple arguments then their
  // var is an array containing those args.
}, {many:true})

// 4. forward()
// communicate between emitters.
// the opposite of watch().
// this will emit an event on the other emitter, optionally with different name.
// the third param is optional. Leave it out and the same event name is used.
// Note the order: event name, emitter, alt name.
// Think of it as:
//   "forward 'some event' to anotherEmitter as 'diff event'"
eventa.forward('some event', anotherEmitter, 'diff event')

// 5. watch()
// communicate between emitters.
// the opposite of forward().
// when an event is emitted on another emitter the eventa will emit it as well,
// optionally with a different event name. Without it the same name is used.
// third argument is a function which receives the event arguments and
// should return an array of arguments to use when re-emitting the event
// on eventa.
// for example, it's useful when a simple notification event on
// a different emitter would benefit from some objects available where
// you are registering the eventa.watch().
// Note the order: other emitter, event name, creator, alt name.
// Think of it as:
//   "watch anotherEmitter 'for some event' and emit with 'these args' as 'diff event'"
eventa.watch(anotherEmitter, 'for some event', null, 'diff event')

// this will cause the eventa to emit the event with those args.
eventa.watch(anotherEmitter, 'for some event', function(arg1, arg2) {
  return [ arg1.someProp, arg2.someOtherProp, 'something else']
})

// these return a handle object with a remove() function:
var handle = eventa.watch(someEmitter, 'some event')
handle.remove()

// 6. watchError()
// a special version of watch().
// it accepts only two args to handle watching 'error' events.
//   1. the other emitter to watch
//   2. the error message to provide with re-emitted error
// the re-emit on eventa is a single argument object with:
//   1. 'error' property containing the message given to watchError()
//   2. 'Error' property containing the error arg the other emitter sent
// also returns a handle with a remove() function.
eventa.watchError(otherEmitter, 'some error message')

// 7. accept()
// returns a function to use in place of callbacks.
// specify names in an array which correspond to the args it may receive.
// for each name with a corresponding arg eventa will emit an event with that
// name and an object with the property 'object' containing the arg.
// it handles the name 'error' special and treats it like watchError() does.
// when specifying the name 'error' specify a second arg with the error message.
const acceptor = eventa.accept(
  [ 'error', 'myfile' ],
  'failed to read my blah file'
)

// if readFile() calls it with an error then eventa will emit an 'error'
// event with an object argument like:
//   error: 'failed to read my blah file'
//   Error: <the error object provided by readFile()
// If a second arg is provided then eventa will emit that as 'myfile'
// with an event object like:
//   object:'the content of that file'
fs.readFile('some/file.ext', 'utf8', acceptor)
```


## Example: Event Driven

A semi-realistic example of an event-driven app:

TODO: make examples/

```javascript
// require and build it in one
const eventa = require('eventa')()

// add some listeners which report to the console some common info.
// these could just as easily use a logging module.

eventa.on('listening', function(server) {
  console.log('server listening on', server.address)
})

eventa.on('closing', function(event) {
  console.log('server closing. Reason:', event.reason)
})

eventa.on('closed', function() { console.log('server closed.') })

eventa.on('client', function(event) {
  // client is `event.object` because we're going to use
  // eventa's accept() function to emit this 'client'.
  // it puts the arg into the event as 'object'.
  const client = event.object

  // store the address() result because it's not
  // available in the 'end' event
  client.storedAddress = client.address()

  console.log('client connected', client.storedAddress)
})

eventa.on('end', function(client) {
  // we use the storedAddress here
  console.log('client connection ended', client.storedAddress)
})


// now load your local modules which will register their own listeners.
// some will add 'start' listeners to know when to begin stuff which
// will instigate other events, such as having a server socket listen().
// some of their listeners will respond by emitting other events which
// will be listened for by other modules.
// load them easily:
eventa.load([
  './db-connect',         // try to connect to a database
  './server-create',      // start a server socket listening
  './client-connections', // handle new client connections
  './decoder',            // decode client data events
  './transformer',        // transform data into documents for the DB
  './db-update'           // update the DB with the new documents
], __dirname)

// an example of what the above './db-connect' looks like:
module.exports = function(eventa) {

  eventa.on('start', function() {

    const mongo = require('mongodb').MongoClient
    const url = process.env.MONGO_URL || 'mongodb://localhost:3001/somename'

    mongo.connect(url, eventa.accept(
      ['error', 'db'], 'error connecting to database'
    ))
  })

  eventa.on('db', function (event) {
    const db = event.object
    function closeDb() { db.close() }
    eventa.once('error', closeDb)
    eventa.once('closed', closeDb)
  })
}

// an example of './server-create':
module.exports = function(eventa) {

  // when we have the `db` we know we're ready to start
  // the server.
  eventa.on('db', function() {

    const net = require('net')
    const acceptor = eventa.accept(['client'])
    const server = net.createServer(acceptor)
    const port = process.env.LISTEN_PORT || 4321
    const host = process.env.LISTEN_HOST || 'localhost'

    eventa.watchError(server, 'server socket error')
    eventa.watch(server, 'close', null, 'closed')

    process.on('SIGTERM', function() {
      eventa.emit('closing', {reason:'SIGTERM'})
      server.close()
    })

    server.listen(port, host, function() {
      eventa.emit('listening', {address:server.address()})
    })

  })
}

// I think you get the idea.
// Write focused functions as listeners.
// put related listeners/emitters in a module.
// for async ops use accept() to emit errors and results.
// load all the modules.
// emit 'start' via start() to get everything going.
// it's possible to listen for dependencies and have other modules
// emit events providing those dependencies.
// waitFor() helps get multiple dependencies to a single listener.
// TODO: put a complete example in an examples/ directory.
```


## Cleanup

It's possible to build up empty info about events no longer in use with zero listeners.

Fix that by running `eventa.cleanup()`. It will recreate the internal arrays anew retaining only event info which has listeners.

Use is very dependent on your application's needs, so, I leave it to you to determine when, if ever, you need to run this.


## Project Source and Distribution

As usual, the CoffeeScript source file **lib/index.coffee** is transpiled to create **lib/index.js**.

That JavaScript file is then used to produce minified and universal module versions.

| type | min | universal | file                 |
|:----:|:---:|:---------:|:---------------------|
| ES5  | no  | no        | **lib/index.js**     |
| ES5  | no  | yes       | **lib/umd.js**       |
| ES5  | yes | yes       | **lib/umd.min.js**   |


These versions are made available via [unpkg.com](http://unpkg.com/eventa@0.4.0).

Loading via a string will try to use `require()` which, won't work in a browser. So, provide the functions instead. If you have suggestions how to better improve this for using eventa in the browser, please, create an Issue and tell me all about it.

TODO: Test the distribution files and their source maps in a browser.


## MIT License
