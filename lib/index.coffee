'use strict'

class Eventa

  # ready's the arrays it uses to track stuff.
  # accepts `options` as an array of modules/functions to load.
  constructor: (options) ->
    @_names = []     # store the event names corresponding to listener arrays
    @_listeners = [] # array of arrays, each element is a listener array
    @_removals = []  # store removers to run
    if Array.isArray options then @load options


  # gets the array of listeners from the array of arrays by searching the
  # array of event names for the right index to use.
  # creates a new array if one doesn't exist.
  # also helps replace an array when we filter out the removals (nulls)
  _listenersFor: (event, array) ->
    index = @_names.indexOf event

    if index is -1
      @_names.push event
      @_listeners.push listeners = []
      listeners

    else if array?
      @_listeners[index] = array

    else
      @_listeners[index]


  # builds and returns a function/closure which finds and nullifies
  # the object in the provided listeners array.
  # used to provide a way to remove a listener via a simple function call.
  # after each time an event's listeners are run it then removes nulls
  _remover: (listeners, object) ->
    -> # find it, conditionally nullify it
      index = listeners.indexOf object
      listeners[index] = null if index > -1
      return


  # a busy version of the usual 'on' function.
  # basically, it adds a listener for the specified event.
  # more advanced:
  #   1. it allows specifying the context to use with listener,
  #   2. and the number of times it should be called (null = infinity)
  # lastly, it also handles the "once" work `count` equals 1
  on: (event, fn, context, count) ->

    # hold the info related to this listener for both execution and auto-removal
    object = { fn, context, count }

    # get our listener array for this event (create it when it doesn't exist)
    listeners = @_listenersFor event

    # add the object to the end.
    # although that seems like the normal thing to do it's important to note
    # it will be run *before* previously added ones because it executes the
    # listener array from last to first.
    listeners.push object

    # generate a remover function for this listener array and object.
    # use it in a returned "handle" object which can be used to call the remover.
    # more functions may be added later so I'm returning an object with
    # a `remove` property instead of the remover itself.
    remove: @_remover listeners, object


  emit: (event) -> # args after the first one are sent to the listeners

    # optimization friendly way to convert `arguments` into an array
    # so we can remove the first element and reuse the array
    args = []
    args.push.apply args, arguments

    # get rid of the event argument
    args.shift()

    # execute the listeners array for the specified event.
    # track if we have any removes to handle so we can filter the array afterward.
    remove = false
    listeners = @_listenersFor event
    for listener, index in listeners

      # if a listener was null'ed but hasn't been filtered out yet, then skip it
      unless listener?
        remove = true
        continue

      # call the listener with the context and args (context may be null)
      listener.fn.apply listener.context, args

      # if the listener is limited to a specified count...
      if listener.count?

        # if decrimenting it would mean it should be removed/null'ed, then do it
        if listener.count < 2
          listeners[index] = null
          remove = true

        else # otherwise, decriment the count
          listener.count--

    if remove # if we removed/null'ed some then filter them out.
      # filter the current array keeping only those which exist (not null'ed).
      # this function can also find where the array is stored and replace it
      @_listenersFor event, listeners.filter (o) -> o?

    return



  # simply emit the start event
  start: -> @emit 'start' ; return



  load: ->

    # optimization friendly way to convert `arguments` into an array
    args = []
    args.push.apply args, arguments

    # iterate the args and determine what to do with them.
    # they should be module paths for exported functions, functions,
    # or an array/object containing them.
    for arg in args

      switch typeof arg

        # a string *should* be a path to a module we can require to get a function
        when 'string' then require(arg) this

        # if it's a function then just call it, yay.
        when 'function' then arg this

        # an object could mean multiple things, hopefully it's something useful
        when 'object'

          # arrays cause a recursive call to this load() function
          if Array.isArray arg then @load.apply this, arg

          # an object is the only way to specify a function with options
          else if arg.fn? then arg.fn this, arg.options

          # otherwise, it's not allowed. :-/
          else console.error 'invalid object argument for load():', arg

        # anything other than string/function/object is invalid
        else console.error 'invalid type of argument for load():', arg

    return



  # forward an event emitted on this Eventa to another `target` emitter
  # `altEvent` allows specifying a new event name to use for the emit.
  forward: (event, target, altEvent) ->

    # NOTE: this returns a handle with a `remove()` function to stop this.
    @on event, ->

      # start with an args array containing the event name to use
      args = [ altEvent ? event ]

      # append all the `arguments` emitted with this event
      args.push.apply args, arguments

      # emit on the target with our args
      target.emit.apply target, args



  # listens for the event on the other emitter.
  # when it occurs, we use the provided `creator` function to
  # generate an "event object" and then emit the event on this Eventa.
  watch: (emitter, event, creator, altEvent) ->

    eventa = this
    reEmitName = altEvent ? event

    # make the listener provide the `arguments` to the creator function
    listener = ->
      # optimization friendly way to convert `arguments` into an array
      args = []
      args.push.apply args, arguments

      # provide those args into the creator function, if it exists.
      # it should return an array. if not, wrap it.
      args = creator.apply creator, args if creator?

      # while wrapping it, stick the event name in the front.
      # if we're not wrapping it, then unshift the event name onto the front.
      unless Array.isArray args then args = [reEmitName, args]
      else args.unshift reEmitName

      # now call emit on this Eventa with the args
      eventa.emit.apply eventa, args

    # now that we have that listener, add it to the other emitter.
    emitter.on event, listener

    # return a handle which easily allows stopping this receive work.
    remove: ->
      # use either whichever function exists. if neither, well, ...
      removeListener = emitter.off ? emitter.removeListener ? emitter.removeEventListener
      if removeListener?
        removeListener.call emitter, event, listener
      else
        console.error 'unable to remove listener from other emitter:', emitter



  # similar to `watch()` above, except, specialized for the 'error' event.
  # basically, when an 'error' is emitted on the other emitter then
  # we emit an 'error' in this Eventa with the specified message and the error.
  watchError: (emitter, message) ->

    eventa = this

    listener = (error) -> eventa.emit 'error', error:message, Error:error

    emitter.on 'error', listener

    remove: ->
      # use either whichever function exists. if neither, well, ...
      removeListener = emitter.off ? emitter.removeListener ? emitter.removeEventListener
      if removeListener?
        removeListener.call emitter, 'error', listener
      else
        console.error 'unable to remove error listener from other emitter:', emitter



  # provides a listener/callback which will use the provided names to
  # emit those events with the object in the corresponding arguments index.
  # for example:
  #   eventa.accept ['thing']
  # returns a function which when called will do:
  #   eventa.emit 'thing', object:arguments[0]
  # it creates an array from `arguments` first, so, slightly different.
  accept: (nameArray, errorMessage) ->

    eventa = this

    ->
      # optimization friendly way to convert `arguments` into an array
      args = []
      args.push.apply args, arguments

      # loop over provided names to emit an event with them if the arg exists
      for name, index in nameArray

        # if there is an arg then emit that event with date and object
        if args[index]?

          if name is 'error' # then handle it special. see `receiveError`, too.
            eventa.emit 'error', error:errorMessage, Error:args[index]

          else
            eventa.emit name, object:args[index]

      return



module.exports = (options) -> new Eventa options
