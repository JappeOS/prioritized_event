import 'dart:async';

import 'package:event/event.dart';
import 'package:event/src/event.dart';
import 'package:event/src/errors.dart';
import 'package:collection/collection.dart';

/// [EventHandler], but with a priority.
class PrioritizedEventHandler<T extends EventArgs> {
  final EventHandler<T> handler;
  final int priority;

  PrioritizedEventHandler(this.handler, [this.priority = 0]);

  @override
  String toString() => '$handler (priority: $priority)';
}

/// Represents an Event as some number of handlers (subscribers) that can be
/// notified when a condition occurs, by using the [broadcast] method.
///
/// See also [EventArgs].
///
/// Note: the example folder contains an example of the Counter app
/// using Events
///
/// =====
///
/// ```dart
/// // An example of a simple Event with no argument.
/// var e = PrioritizedEvent();
/// e.subscribe(PrioritizedEventHandler((args) => print('changed'), 1)); // add a handler
/// e.broadcast(); // broadcast the Event to subscribers
/// // outputs "changed" to console
///
/// // An example of an Event broadcasting a custom argument (see EventArgs).
/// var e = Event<MyChangedValue>();
/// e.subscribe(PrioritizedEventHandler((args) => print(args.changedValue), 1)); // add a handler
/// e.broadcast(MyChangedValue(37)); // broadcast the Event to subscribers
/// // outputs 37 to console
/// ```
class PrioritizedEvent<T extends EventArgs> {
  int eventHandlerComparator(PrioritizedEventHandler a, PrioritizedEventHandler b) => b.priority.compareTo(a.priority);

  /// An optional name for the [PrioritizedEvent]
  final String eventName;

  /// The handlers (subscribers) associated with this [PrioritizedEvent]. Instantiated
  /// lazily (on demand) to reflect that an [PrioritizedEvent] may have no subscribers,
  /// and if so, should not incur the overhead of instantiating an empty [PriorityQueue].
  late final PriorityQueue<PrioritizedEventHandler> _handlers = PriorityQueue<PrioritizedEventHandler>(eventHandlerComparator);

  /// Constructor creates a new Event with an optional [eventName] to identify the [PrioritizedEvent].
  ///
  /// To specify that the Event broadcasts values via an EventArgs derived class,
  /// set the generic type, e.g.
  /// ``` dart
  /// var e = PrioritizedEvent<Value<int>>();
  /// ```
  ///
  /// Not specifying a generic type means that an EventArgs object will be
  /// broadcast, e.g. the following are equivalent...
  /// ``` dart
  /// var e = PrioritizedEvent();
  /// // equivalent to
  /// var e = PrioritizedEvent<EventArgs>();
  /// ```
  PrioritizedEvent([this.eventName = ""]);

  /// Gets this Events generic type. If not explicitly set, will be [EventArgs], e.g.
  /// ``` dart
  /// var e = PrioritizedEvent();
  ///  // is equivalent to
  /// var e = PrioritizedEvent<EventArgs>();
  /// ```
  Type get genericType => T;

  /// Adds a handler (callback) that will be executed when this
  /// [PrioritizedEvent] is raised using the [broadcast] method.
  ///
  /// ```dart
  /// // Example
  /// counter.onValueChanged.subscribe(PrioritizedEvent((args) => print('value changed'), 1));
  /// ```
  void subscribe(PrioritizedEventHandler<T> handler) {
    _handlers.add(handler);
    log('Subscribed to Event "$this"', source: "Event", level: Severity.debug);
  }

  /// Subscribes a Stream [StreamSink] to an Event.
  ///
  /// This allows a sequence of broadcast Events to
  /// be represented and manipulated as a Stream. The
  /// rich range of mechanisms to filter and manipulate
  /// a Stream become available.
  ///
  /// Remember that the supplied [StreamSink] should
  /// be closed when no longer needed.
  ///
  /// ```dart
  /// // Example
  ///  var e = PrioritizedEvent();
  ///  var sc = StreamController();
  ///
  ///  e.subscribeStream(1, sc.sink);
  ///  e.broadcast();
  ///
  ///  sc.stream.listen((e) => print('boom'));
  ///  sc.close();
  /// ```
  void subscribeStream(int priority, StreamSink sink) {
    _handlers.add(PrioritizedEventHandler<T>((args) => sink.add(args), priority));
  }

  /// Removes a handler previously added to this [PrioritizedEvent].
  ///
  /// Returns `true` if handler was in list, `false` otherwise.
  /// This method has no effect if the handler is not in the list.
  ///
  /// Important: There is no way to unsubscribe anonymous handlers
  /// (other than with [unsubscribeAll]) as there is no way to
  /// identify the handler your seeking to unsubscribe.
  bool unsubscribe(PrioritizedEventHandler<T> handler) {
    return _handlers.remove(handler);
  }

  /// Removes all subscribers (handlers).
  void unsubscribeAll() {
    _handlers.clear();
  }

  /// Returns the number of handlers (subscribers).
  /// ```dart
  /// // Example
  /// int numberOfHandlers = myEvent.subscriberCount
  /// ```
  int get subscriberCount {
    return _handlers.length;
  }

  /// Broadcast this [PrioritizedEvent] to subscribers, with an optional [EventArgs] derived
  /// argument.
  ///
  /// Ignored if no handlers (subscribers).
  /// Calls each handler (callback) that was previously added to this [PrioritizedEvent].
  ///
  /// Returns true if there are associated subscribers, or else false if there
  /// are no subscribers and the broadcast has no effect.
  ///
  /// ```dart
  /// // Example
  /// // Without an <EventArgs> argument
  /// var e = PrioritizedEvent();
  /// e.broadcast();
  ///
  /// // Note: above is equivalent to...
  /// var e = PrioritizedEvent<EventArgs>();
  /// e.broadcast(EventArgs());
  ///
  /// // With an <EventArgs> argument
  /// var e = PrioritizedEvent<ChangedValue>();
  /// e.broadcast(ChangedValue(3.14159));
  /// ```
  /// If the broadcast argument does not match the
  /// Event generic type, then an [ArgsError] will be thrown.
  bool broadcast([args]) {
    if (_handlers.isEmpty) return false;

    // if no EventArgs or derived specified, then create one
    args ??= EventArgs();
    args.eventName = this.eventName;
    args.whenOccurred = DateTime.now().toUtc();

    try {
      while (_handlers.isNotEmpty) {
        log('Broadcast Event "$this"', source: "Event", level: Severity.debug);

        _handlers.removeFirst().handler.call(args);
      }
    } on TypeError {
      throw ArgsError("Incorrect args being broadcast - args should be a $genericType");
    }

    return true;
  }

  /// Notify subscribers that this [PrioritizedEvent] occurred, with an optional [EventArgs] derived
  /// argument. A direct equivalent of the `broadcast` method.
  ///
  /// Ignored if no handlers (subscribers).
  /// Calls each handler (callback) that was previously added to this [PrioritizedEvent].
  ///
  /// Returns true if there are associated subscribers, or else false if there
  /// are no subscribers and the broadcast has no effect.
  ///
  /// ```dart
  /// // Example
  /// // Without an <EventArgs> argument
  /// var e = PrioritizedEvent();
  /// e.notifySubscribers();
  ///
  /// // Note: above is equivalent to...
  /// var e = PrioritizedEvent<EventArgs>();
  /// e.notifySubscribers(EventArgs());
  ///
  /// // With an <EventArgs> argument
  /// var e = PrioritizedEvent<ChangedValue>();
  /// e.notifySubscribers(ChangedValue(3.14159));
  /// ```
  /// If the notifySubscribers argument does not match the
  /// Event generic type, then an [ArgsError] will be thrown.
  bool notifySubscribers([args]) {
    return broadcast(args);
  }

  /// Represent this [PrioritizedEvent] as its (optional) name + Type
  @override
  String toString() {
    if (eventName.isEmpty) {
      return "Unnamed:${runtimeType.toString()}";
    } else {
      return "$eventName:${runtimeType.toString()}";
    }
  }
}