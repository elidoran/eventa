# eventa
[![Build Status](https://travis-ci.org/elidoran/eventa.svg?branch=master)](https://travis-ci.org/elidoran/eventa)
[![Dependency Status](https://gemnasium.com/elidoran/eventa.png)](https://gemnasium.com/elidoran/eventa)
[![npm version](https://badge.fury.io/js/eventa.svg)](http://badge.fury.io/js/eventa)
[![Coverage Status](https://coveralls.io/repos/github/elidoran/eventa/badge.svg?branch=master)](https://coveralls.io/github/elidoran/eventa?branch=master)

Simple advanced central event communicator.


## Install

```sh
npm install eventa --save
```


## Usage


```javascript
    // package returns a builder function
var buildEventa = require('eventa')
    // provide an array of things to load at build time
  , eventa = buildEventa(['some-package', './local-module'])

// also load explicitly via load()
eventa.load(
  './local-module2',
  './local-module3'
)

// it has the standard EventEmitter style functions
eventa.on('someEvent', function() { /* do something */ })
eventa.emit('someEvent', 'blah1', {blah:'two'})

// functions return an object with a `remove` property to remove listeners.
var handle = eventa.on('event name', function() {})
// then you can remove it at any time:
handle.remove()
// you can even do that while inside the listener:
var theHandle = eventa.on('name', function() { theHandle.remove() })

// instead of a once() function, you can specify the number of times
// a listener is allowed to run. Specify 1 for a "once" listener:
eventa.on('one time', function(){}, null, 1)
eventa.on('counted 5 times', function(){}, null, 5)

// what's that null?
// event listener functions run without a context, usually.
// specify a context object as the third parameter:
eventa.on('e', function(){}, {some:'context'})


// eventa helps with building an event-driven setup so it has extra functions:

// 1. start()
// simply emits a start event. It may develop into more later,
// for now, it's simple.
// add listeners to the 'start' event which will begin the parts of your
// app which instigate/initiate things, such as a server socket or timer.
eventa.start()

// 2. load()
// easily load in local modules or published packages.
// they'll receive the instance of the eventa as an argument,
// and optionally, an options object.
// break up the code into modules exporting a function which
// receives the eventa and adds their own listeners and code to emit events.
// provide:
//  1. the path to a module as a string
//  2. the function accepting the eventa
//  3. an object with a `fn` property containing the function,
//     may also have an `options` property which will be the second arg.
//  4. an array containing any of the above three
eventa.load('./local/module')
eventa.load('published-package')
eventa.load(function (eventa) { eventa.on('blah', function(){})})
// this looks odd with both supplied here.
// imagine you received the function from a require/import call.
// or, imagine the options are provided to you from elsewhere.
eventa.load({
  fn: function (eventa, options) { /* blah */ },
  options: { some:'options object'}
})

// 3. forward()
// communicate between emitters.
// when an event is emitted on the eventa, emit it on a different emitter.
// optionally with a different event name.
// this will forward 'some event' to `anotherEmitter` as 'diff event'.
// the third param is optional. Leave it out and the same event name is used.
// Note the order: event name, emitter, alt name.
// "forwarding" forwards an eventa event to the other emitter.
eventa.forward('some event', anotherEmitter, 'diff event')

// 4. watch()
// communicate between emitters.
// this is the opposite of forward().
// when an event is emitted on another emitter the eventa will emit it as well,
// optionally with a different event name. Without it the same name is used.
// third argument is a function which receives the event arguments and
// should return an array of arguments to use when re-emitting the event
// on eventa.
// for example, this is useful when a simple notification event on
// a different emitter is a reason to emit your own event with different
// args. Such as a socket 'end' event leading to emitting an event
// to tell something else what to do now with info about that client.
// Note the order: other emitter, event name, creator, alt name.
// It's different than forward(), opposite, because they are opposites.
// "watch" listens to another emitter for some event to use.
eventa.watch(anotherEmitter, 'for some event', null, 'diff event')
// this will cause the eventa to emit the event with those args.
eventa.watch(anotherEmitter, 'for some event', function(arg1, arg2) {
  return [ arg1.someProp, arg2.someOtherProp, 'something else']
})
// these return a handle object with a remove() function:
var handle = eventa.watch(someEmitter, 'some event')
handle.remove()

// 5. watchError()
// a special version of watch().
// it accepts only two args to handle watching 'error' events.
//   1. the other emitter to watch
//   2. the error message to provide with re-emitted errorMessage
// the re-emit on eventa is an object with:
//   1. 'error' property containing the message given to watchError()
//   2. 'Error' property containing the error arg the other emitter sent
// also returns a handle with a remove() function.
eventa.watchError(otherEmitter, 'some error message')

// 6. accept()
// returns a function to use in place of callbacks.
// specify names in an array which correspond to the args it may receive.
// for each name with a corresponding arg eventa will emit an event with that
// name and an object with the property 'object' containing the arg.
// it handles the name 'error' special and treats it like watchError() does.
// when specifying the name 'error' specify a second arg with the error message.
var acceptor = eventa.accept(['error', 'myfile'], 'failed to read my blah file')
// if readFile() calls it with an error then eventa will emit an 'error'
// event with an object argument like:
//   error: 'failed to read my blah file'
//   Error: <the error object provided by readFile()
// If a second arg is provided then eventa will emit that as 'myfile'
// with an event object like:
//   object:'the content of that file'
fs.readFile('some/file.ext', 'utf8', acceptor)
```


## Event Driven

A more realistic example of an event-driven app:

```javascript
var eventa = require('eventa')()

// add some listeners which report to the console some common info:

eventa.on('listening', function(event) {
  console.log('server listening on', event.address)
})

eventa.on('closing', function(event) {
  console.log('server closing. Reason:',event.reason)
})

eventa.on('closed', function() { console.log('server closed.') })

eventa.on('client', function(event) {
  event.object.storedAddress = event.object.address()
  console.log('client connected',event.object.storedAddress)
})

eventa.on('end', function(client) {
  console.log('client connection ended', client.storedAddress)
})


// now load your local modules which will register their own listeners.
// some will add 'start' listeners to know when to begin stuff which
// will instigate other events, such as having a server socket listen().
// some of their listeners will respond by emitting other events which
// will be listened for by other modules.
// load them easily:
eventa.load(
  './db-connect',         // try to connect to a database
  './server-create',      // start a server socket listening
  './client-connections', // handle new client connections
  './decoder',            // decode client data events
  './transformer',        // transform data into documents for the DB
  './db-update'           // update the DB with the new documents
)

// an example of what the above './db-connect' looks like:
module.exports = function(eventa) {

  eventa.on('start', function() {

    var mongo = require('mongodb').MongoClient
      , url = process.env.MONGO_URL || 'mongodb://localhost:3001/somename'

    mongo.connect(url, eventa.accept(['error', 'db']))
  })

  eventa.on('db', function (event) {
    db = event.object
    function closeDb() { db.close() }
    eventa.on('error', closeDb, null, 1)
    eventa.on('closed', closeDb, null, 1)
  })
}

// an example of './server-create':
module.exports = function(eventa) {

  eventa.on('db', function() {

    var net = require('net')
      , server = net.createServer(eventor.accept(['client']))
      , port = process.env.LISTEN_PORT || 4321
      , host = process.env.LISTEN_HOST || 'localhost'

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
// load all the modules.
// emit 'start' via start() to get everything going.
// it's possible to listen for dependencies and have other modules
// emit events containing those dependencies.
```


## Project Source and Distribution

As usual, the CoffeeScript source file **lib/index.coffee** is transpiled to create **lib/index.js**.

That JavaScript file is then used to produce minified and universal module versions.

| type | min | universal | file                 |
|:----:|:---:|:---------:|:---------------------|
| ES5  | no  | no        | **lib/index.js**     |
| ES5  | no  | yes       | **lib/umd.js**       |
| ES5  | yes | yes       | **lib/umd.min.js**   |


These versions are made available via [unpkg.com](http://unpkg.com/eventa@0.1.0).

TODO: Test the distribution files and their source maps in a browser.


## MIT License
