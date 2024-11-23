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
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrioritizedEventHandler && other.handler == handler;
  }

  @override
  int get hashCode => handler.hashCode;

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
  int eventHandlerComparator(PrioritizedEventHandler<T> a, PrioritizedEventHandler<T> b) => b.priority.compareTo(a.priority);

  /// An optional name for the [PrioritizedEvent]
  final String eventName;

  /// The handlers (subscribers) associated with this [PrioritizedEvent]. Instantiated
  /// lazily (on demand) to reflect that an [PrioritizedEvent] may have no subscribers,
  /// and if so, should not incur the overhead of instantiating an empty [PriorityQueue].
  late final List<PrioritizedEventHandler<T>> _handlers = [];

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

  /// Internal function to add a handler to the [_handlers] list properly.
  void _addHandler(PrioritizedEventHandler<T> handler) {
    int _binarySearch(PrioritizedEventHandler<T> handler) {
      int low = 0;
      int high = _handlers.length - 1;

      while (low <= high) {
        final mid = (low + high) ~/ 2;
        final comparison = eventHandlerComparator(handler, _handlers[mid]);

        if (comparison < 0) {
          low = mid + 1; // Move to the upper half
        } else if (comparison > 0) {
          high = mid - 1; // Move to the lower half
        } else {
          return mid; // Found exact match (rare case, for equal priority)
        }
      }

      return low; // Return the index to insert (maintains sorted order)
    }

    final index = _binarySearch(handler);
    if (index == -1) {
      _handlers.add(handler); // Append if no lower-priority item is found
    } else {
      _handlers.insert(index, handler); // Insert at the found index
    }
  }

  /// Adds a handler (callback) that will be executed when this
  /// [PrioritizedEvent] is raised using the [broadcast] method.
  ///
  /// ```dart
  /// // Example
  /// counter.onValueChanged.subscribe(PrioritizedEvent((args) => print('value changed'), 1));
  /// ```
  void subscribe(PrioritizedEventHandler<T> handler) {
    _addHandler(handler);
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
    _addHandler(PrioritizedEventHandler<T>((args) => sink.add(args), priority));
  }

  /// Removes a handler previously added to this [PrioritizedEvent].
  ///
  /// Returns `true` if handler was in list, `false` otherwise.
  /// This method has no effect if the handler is not in the list.
  ///
  /// Important: There is no way to unsubscribe anonymous handlers
  /// (other than with [unsubscribeAll]) as there is no way to
  /// identify the handler your seeking to unsubscribe.
  bool unsubscribe(EventHandler<T> handler) {
    return _handlers.remove(PrioritizedEventHandler<T>(handler));
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
      for (final handler in _handlers) {
        log('Broadcast Event "$this"', source: "Event", level: Severity.debug);

        handler.handler.call(args);
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