'use strict'

const pathResolve = require('path').resolve

class Eventa {

  // ready the array it uses to store info.
  // accepts `options` as an array of modules/functions to load.
  constructor(thing, options, dir) {

    this._info = []

    if (thing) {
      this.load(thing, options, dir)
    }
  }

  // gets the array of listeners from the info array by searching the
  // array for the matching event name.
  // creates a new event entry in the array if one doesn't exist.
  _listeners(event) {

    const array  = this._info
    const length = array.length

    for (let i = 0; i < length; i++) {

      const info = array[i]

      if (info.name === event) {
        return info.listeners
      }
    }

    array[length] = {
      name: event,
      listeners: []
    }

    return array[length].listeners
  }

  // builds and returns a function/closure which finds and nullifies
  // the object in the provided listeners array.
  // used to provide a way to remove a listener via a simple function call.
  // the emit() function will clean up nulls after it runs thru the listeners
  _remover(listeners, object) {

    return function() { // find it, conditionally nullify it

      const index = listeners.indexOf(object)

      if (index > -1) {
        listeners[index] = null
      }
    }
  }

  // it's possible to buildup elements in the info array with empty listener
  // arrays which aren't being used anymore.
  // this function eliminates those.
  // NOTE: emit() triggers removing null'ed elements in listeners array.
  // so, cleanup() won't clean up if there hasn't been an emit()
  cleanup() {

    const clean = this._cleanListeners

    return this._info = this._info.filter(function(info) {

      // let's also rebuild the listeners array
      info.listeners = info.listeners.filter(function(el) {
        return el != null
      })

      return clean(info.listeners).length > 0
    })
  }

  // look thru array and shift existing elements left to compact them together.
  _cleanListeners(listeners) {

    let shift = 0

    for (let i = 0; i < listeners.length; i++) {

      const el = listeners[i]

      if (el == null) {
        shift++
      }

      else if (shift > 0) {
        listeners[i - shift] = el
      }
    }

    // truncate the array (set length) to new length.
    // NOTE: testing showed Node eliminates elements after the length,
    // so, we won't null them explicitly.
    if (shift > 0) {
      listeners.length = listeners.length - shift
    }

    // TODO: if final length is zero then we could remove the event completely,
    //       we'd need the event name too
    return listeners
  }

  // a convenience for:
  //   eventa.on('event', listener, null, 1)
  once(event, fn, context) {
    return this.on(event, fn, context, 1)
  }

  // a busy version of the usual 'on' function.
  // basically, it adds a listener for the specified event.
  // more advanced:
  //   1. it allows specifying the context to use with listener,
  //   2. and the number of times it should be called (null = infinity)
  // lastly, it also handles the "once" work using `count` as 1
  on(event, fn, context, count) {

    // hold the info related to this listener for both execution and auto-removal
    // NOTE: both `context` and `count` may be undefined or null.
    const object = {fn, context, count}

    // get our listener array for this event (create it when it doesn't exist)
    const listeners = this._listeners(event)

    // add the object to the end.
    // although that seems like the normal thing to do it's important to note
    // it will be run *before* previously added ones because it executes the
    // listener array from last to first.
    listeners[listeners.length] = object

    return {
      // generate a remover function for this listener array and object.
      // use it in a returned "handle" object which can be used to call the remover.
      // more functions may be added later so I'm returning an object with
      // a `remove` property instead of the remover itself.
      remove: this._remover(listeners, object)
    }
  }

  emit(event) { // args after the first one are sent to the listeners

    // optimization friendly way to convert `arguments` into an array
    // so we can remove the first element and reuse the array
    const args = []
    args.push.apply(args, arguments)
    // console.log('arguments', arguments)
    // console.log('args', args)
    // get rid of the event argument
    args.shift()
    // console.log('args, post shift()', args)
    // execute the listeners array for the specified event.
    // track if we have any removes to handle so we can filter the array afterward.
    let remove = false

    const listeners = this._listeners(event)

    // 'by -1' means 'back-to-front order'
    for (let index = listeners.length - 1; index >= 0; index--) {

      const listener = listeners[index]

      // if a listener was null'ed but hasn't been filtered out yet, then skip it
      if (listener == null) {
        remove = true
        continue
      }

      // call the listener with the context and args (context may be null)
      listener.fn.apply(listener.context, args)

      // if the listener is limited to a specified count...
      if (listener.count != null) {

        // if decrimenting it would mean it should be removed/null'ed, then do it
        if (listener.count < 2) {
          listeners[index] = null
          remove = true // otherwise, decriment the count
        }

        else {
          listener.count--
        }
      }
    }

    // if there are some to get rid of ...
    if (remove) {
      this._cleanListeners(listeners)
    }
  }

  // simply emit the start event
  start() {
    this.emit('start')
  }

  _isLocalPath(arg) {
    return arg[0] === '.' && (arg[1] === '/' || (arg[1] === '.' && arg[2] === '/'))
  }

  load(arg1, arg2, arg3) {

    const thing   = arg1
    const options = typeof arg2 === 'string' ? null : arg2
    const dir     = typeof arg2 === 'string' ? arg2 : arg3

    if (Array.isArray(thing)) {
      for (let i = 0; i < thing.length; i++) {

        const each = thing[i]

        this.load(each, options, dir)
      }

      return
    }

    // now we know it's not an array argument, and we know the options and dir.
    switch (typeof thing) {

      case 'string':

        if (this._isLocalPath(thing)) {

          // get resolve if we haven't already
          if (this.resolve == null) {
            this.resolve = pathResolve
          }

          // resolve against the provided base dir or '.'
          const path = this.resolve(dir || '.', thing)
          require(path)(this, options)
        }

        else {
          require(thing)(this, options)
        }

        break

      case 'function':
        thing(this, options)
        break

      default:
        console.error('invalid type of argument for load():', thing)
    }
  }

  // forward an event emitted on this Eventa to another `target` emitter
  // `altEvent` allows specifying a new event name to use for the emit.
  forward(event, target, altEvent) {

    // NOTE: this returns a handle with a `remove()` function to stop this.
    return this.on(event, function() {

      // start with an args array containing the event name to use
      const args = [altEvent || event]

      // append all the `arguments` emitted with this event
      args.push.apply(args, arguments)

      // emit on the target with our args
      return target.emit.apply(target, args)
    })
  }

  // listens for the event on the other emitter.
  // when it occurs, we use the provided `creator` function to
  // generate an "event object" and then emit the event on this Eventa.
  watch(emitter, event, creator, altEvent) {

    const eventa = this

    const reEmitName = altEvent || event

    // make the listener provide the `arguments` to the creator function
    const listener = function() {

      // optimization friendly way to convert `arguments` into an array
      let args = []

      args.push.apply(args, arguments)

      if (creator) {
        // provide those args into the creator function, if it exists.
        // it should return an array. if not, wrap it.
        args = creator.apply(creator, args)
      }

      // while wrapping it, stick the event name in the front.
      // if we're not wrapping it, then unshift the event name onto the front.
      // NOTE: yes, we made `args` an array above, but, if `creator` ran then
      //       we have the `args` it provided which may not be an array.
      if (!Array.isArray(args)) {
        args = [reEmitName, args]
      }

      else {
        args.unshift(reEmitName)
      }

      // now call emit on this Eventa with the args
      return eventa.emit.apply(eventa, args)
    }

    // now that we have that listener, add it to the other emitter.
    emitter.on(event, listener)

    return {
      // return a handle which easily allows stopping this receive work.
      remove: function() {

        // use the function which exists. if none, well, ...
        const removeListener = emitter.off || emitter.removeListener || emitter.removeEventListener

        if (removeListener) {
          return removeListener.call(emitter, event, listener)
        }

        else {
          return console.error('unable to remove listener from other emitter:', emitter)
        }
      }
    }
  }

  // similar to `watch()` above, except, specialized for the 'error' event.
  // basically, when an 'error' is emitted on the other emitter then
  // we emit an 'error' in this Eventa with the specified message and the error.
  watchError(emitter, message) {

    const eventa = this

    const listener = function(error) {
      return eventa.emit('error', {
        error: message,
        Error: error
      })
    }

    emitter.on('error', listener)

    return {
      remove: function() {

        // use either whichever function exists. if neither, well, ...
        const removeListener = emitter.off || emitter.removeListener || emitter.removeEventListener

        if (removeListener) {
          return removeListener.call(emitter, 'error', listener)
        }

        else {
          return console.error('unable to remove error listener from other emitter:', emitter)
        }
      }
    }
  }

  // provides a listener/callback which will use the provided names to
  // emit those events with the object in the corresponding arguments index.
  // for example:
  //   eventa.accept ['thing']
  // returns a function which when called will do:
  //   eventa.emit 'thing', object:arguments[0]
  // it creates an array from `arguments` first, so, slightly different.
  accept(nameArray, errorMessage) {

    const eventa = this

    return function() {

      // optimization friendly way to convert `arguments` into an array
      const args = []

      args.push.apply(args, arguments)

      // loop over provided names to emit an event with them if the arg exists
      for (let index = 0, length = nameArray.length; index < length; index++) {

        const name = nameArray[index]

        // if there is an arg then emit that event with date and object
        if (args[index]) {

          if (name === 'error') { // then handle it special. see `receiveError`, too.
            eventa.emit('error', {
              error: errorMessage,
              Error: args[index]
            })
          }

          else {
            eventa.emit(name, {
              object: args[index]
            })
          }// end else
        } // end if(args[index])
      } // end for-loop
    } // end closure created in accept()
  } // end accept()

  // like on() but for combining multiple events.
  // waits for all specified events to occur before calling the listener.
  // if there are multiple arguments to one or more event, set `many` option:
  //   eventa.waitFor(['a', 'b', 'c'], fn, class, {many:true})
  waitFor(nameArray, fn, context, options) {

    // when callbacks receive results they are placed into this array.
    // NOTE: let's predefine its length because we assign results directly in.
    const results  = new Array(nameArray.length)

    // we are adding listeners and storing their removers into this array
    // to return to the caller of waitFor().
    const removers = new Array(nameArray.length)

    // check if the "many" option is true once and reuse later.
    const many = options && (options.many === true)

    // count how many results we've received so we know when we have them all.
    let count = 0

    // iterate over each name. use forEach() so the function call gives us a scope
    // to create closures in during the loop.
    nameArray.forEach((event, index) => {

      // add an "on listener" and store its remover.
      const waitListener = function(arg) {

        // if we received one we haven't received before then increment the count.
        if (results[index] == null) {
          count++
        }

        // if they tell us there are multiple args from the event,
        // then gather them up into a new array.
        if (many) {

          // copy `args` so we can store them in `results` for later.
          const args = []
          args.push.apply(args, arguments)

          // still check if there's only one to provide it direct
          results[index] = (args.length === 1) ? args[0] : args
        }

        // otherwise set the one arg we have into results array.
        else {
          results[index] = arg
        }

        // if the count matches then we have all the results,
        // so let's send them to the final callback function.
        if (count === nameArray.length) {
          fn.apply(context, results.slice()) // copy the array
          count = 0
          results.fill(null) // empty results
        }
      }

      removers[removers.length] = this.on(event, waitListener)
    })

    // return the array of removers so the caller can cancel them.
    return removers
  }

}

module.exports = function(options, dir) {
  return new Eventa(options, dir)
}
