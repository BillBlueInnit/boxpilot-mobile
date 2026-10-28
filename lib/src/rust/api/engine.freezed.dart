// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'engine.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CoreState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CoreState()';
}


}

/// @nodoc
class $CoreStateCopyWith<$Res>  {
$CoreStateCopyWith(CoreState _, $Res Function(CoreState) __);
}


/// Adds pattern-matching-related methods to [CoreState].
extension CoreStatePatterns on CoreState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CoreState_Stopped value)?  stopped,TResult Function( CoreState_Starting value)?  starting,TResult Function( CoreState_Running value)?  running,TResult Function( CoreState_Stopping value)?  stopping,TResult Function( CoreState_Failed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CoreState_Stopped() when stopped != null:
return stopped(_that);case CoreState_Starting() when starting != null:
return starting(_that);case CoreState_Running() when running != null:
return running(_that);case CoreState_Stopping() when stopping != null:
return stopping(_that);case CoreState_Failed() when failed != null:
return failed(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CoreState_Stopped value)  stopped,required TResult Function( CoreState_Starting value)  starting,required TResult Function( CoreState_Running value)  running,required TResult Function( CoreState_Stopping value)  stopping,required TResult Function( CoreState_Failed value)  failed,}){
final _that = this;
switch (_that) {
case CoreState_Stopped():
return stopped(_that);case CoreState_Starting():
return starting(_that);case CoreState_Running():
return running(_that);case CoreState_Stopping():
return stopping(_that);case CoreState_Failed():
return failed(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CoreState_Stopped value)?  stopped,TResult? Function( CoreState_Starting value)?  starting,TResult? Function( CoreState_Running value)?  running,TResult? Function( CoreState_Stopping value)?  stopping,TResult? Function( CoreState_Failed value)?  failed,}){
final _that = this;
switch (_that) {
case CoreState_Stopped() when stopped != null:
return stopped(_that);case CoreState_Starting() when starting != null:
return starting(_that);case CoreState_Running() when running != null:
return running(_that);case CoreState_Stopping() when stopping != null:
return stopping(_that);case CoreState_Failed() when failed != null:
return failed(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  stopped,TResult Function()?  starting,TResult Function()?  running,TResult Function()?  stopping,TResult Function( String field0)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CoreState_Stopped() when stopped != null:
return stopped();case CoreState_Starting() when starting != null:
return starting();case CoreState_Running() when running != null:
return running();case CoreState_Stopping() when stopping != null:
return stopping();case CoreState_Failed() when failed != null:
return failed(_that.field0);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  stopped,required TResult Function()  starting,required TResult Function()  running,required TResult Function()  stopping,required TResult Function( String field0)  failed,}) {final _that = this;
switch (_that) {
case CoreState_Stopped():
return stopped();case CoreState_Starting():
return starting();case CoreState_Running():
return running();case CoreState_Stopping():
return stopping();case CoreState_Failed():
return failed(_that.field0);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  stopped,TResult? Function()?  starting,TResult? Function()?  running,TResult? Function()?  stopping,TResult? Function( String field0)?  failed,}) {final _that = this;
switch (_that) {
case CoreState_Stopped() when stopped != null:
return stopped();case CoreState_Starting() when starting != null:
return starting();case CoreState_Running() when running != null:
return running();case CoreState_Stopping() when stopping != null:
return stopping();case CoreState_Failed() when failed != null:
return failed(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class CoreState_Stopped extends CoreState {
  const CoreState_Stopped(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreState_Stopped);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CoreState.stopped()';
}


}




/// @nodoc


class CoreState_Starting extends CoreState {
  const CoreState_Starting(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreState_Starting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CoreState.starting()';
}


}




/// @nodoc


class CoreState_Running extends CoreState {
  const CoreState_Running(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreState_Running);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CoreState.running()';
}


}




/// @nodoc


class CoreState_Stopping extends CoreState {
  const CoreState_Stopping(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreState_Stopping);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CoreState.stopping()';
}


}




/// @nodoc


class CoreState_Failed extends CoreState {
  const CoreState_Failed(this.field0): super._();
  

 final  String field0;

/// Create a copy of CoreState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreState_FailedCopyWith<CoreState_Failed> get copyWith => _$CoreState_FailedCopyWithImpl<CoreState_Failed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreState_Failed&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'CoreState.failed(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CoreState_FailedCopyWith<$Res> implements $CoreStateCopyWith<$Res> {
  factory $CoreState_FailedCopyWith(CoreState_Failed value, $Res Function(CoreState_Failed) _then) = _$CoreState_FailedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CoreState_FailedCopyWithImpl<$Res>
    implements $CoreState_FailedCopyWith<$Res> {
  _$CoreState_FailedCopyWithImpl(this._self, this._then);

  final CoreState_Failed _self;
  final $Res Function(CoreState_Failed) _then;

/// Create a copy of CoreState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CoreState_Failed(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent()';
}


}

/// @nodoc
class $UiEventCopyWith<$Res>  {
$UiEventCopyWith(UiEvent _, $Res Function(UiEvent) __);
}


/// Adds pattern-matching-related methods to [UiEvent].
extension UiEventPatterns on UiEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiEvent_Status value)?  status,TResult Function( UiEvent_Log value)?  log,TResult Function( UiEvent_Traffic value)?  traffic,TResult Function( UiEvent_Subscriptions value)?  subscriptions,TResult Function( UiEvent_Settings value)?  settings,TResult Function( UiEvent_CoreInfo value)?  coreInfo,TResult Function( UiEvent_Proxies value)?  proxies,TResult Function( UiEvent_Delays value)?  delays,TResult Function( UiEvent_RuleProviders value)?  ruleProviders,TResult Function( UiEvent_Notice value)?  notice,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiEvent_Status() when status != null:
return status(_that);case UiEvent_Log() when log != null:
return log(_that);case UiEvent_Traffic() when traffic != null:
return traffic(_that);case UiEvent_Subscriptions() when subscriptions != null:
return subscriptions(_that);case UiEvent_Settings() when settings != null:
return settings(_that);case UiEvent_CoreInfo() when coreInfo != null:
return coreInfo(_that);case UiEvent_Proxies() when proxies != null:
return proxies(_that);case UiEvent_Delays() when delays != null:
return delays(_that);case UiEvent_RuleProviders() when ruleProviders != null:
return ruleProviders(_that);case UiEvent_Notice() when notice != null:
return notice(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiEvent_Status value)  status,required TResult Function( UiEvent_Log value)  log,required TResult Function( UiEvent_Traffic value)  traffic,required TResult Function( UiEvent_Subscriptions value)  subscriptions,required TResult Function( UiEvent_Settings value)  settings,required TResult Function( UiEvent_CoreInfo value)  coreInfo,required TResult Function( UiEvent_Proxies value)  proxies,required TResult Function( UiEvent_Delays value)  delays,required TResult Function( UiEvent_RuleProviders value)  ruleProviders,required TResult Function( UiEvent_Notice value)  notice,}){
final _that = this;
switch (_that) {
case UiEvent_Status():
return status(_that);case UiEvent_Log():
return log(_that);case UiEvent_Traffic():
return traffic(_that);case UiEvent_Subscriptions():
return subscriptions(_that);case UiEvent_Settings():
return settings(_that);case UiEvent_CoreInfo():
return coreInfo(_that);case UiEvent_Proxies():
return proxies(_that);case UiEvent_Delays():
return delays(_that);case UiEvent_RuleProviders():
return ruleProviders(_that);case UiEvent_Notice():
return notice(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiEvent_Status value)?  status,TResult? Function( UiEvent_Log value)?  log,TResult? Function( UiEvent_Traffic value)?  traffic,TResult? Function( UiEvent_Subscriptions value)?  subscriptions,TResult? Function( UiEvent_Settings value)?  settings,TResult? Function( UiEvent_CoreInfo value)?  coreInfo,TResult? Function( UiEvent_Proxies value)?  proxies,TResult? Function( UiEvent_Delays value)?  delays,TResult? Function( UiEvent_RuleProviders value)?  ruleProviders,TResult? Function( UiEvent_Notice value)?  notice,}){
final _that = this;
switch (_that) {
case UiEvent_Status() when status != null:
return status(_that);case UiEvent_Log() when log != null:
return log(_that);case UiEvent_Traffic() when traffic != null:
return traffic(_that);case UiEvent_Subscriptions() when subscriptions != null:
return subscriptions(_that);case UiEvent_Settings() when settings != null:
return settings(_that);case UiEvent_CoreInfo() when coreInfo != null:
return coreInfo(_that);case UiEvent_Proxies() when proxies != null:
return proxies(_that);case UiEvent_Delays() when delays != null:
return delays(_that);case UiEvent_RuleProviders() when ruleProviders != null:
return ruleProviders(_that);case UiEvent_Notice() when notice != null:
return notice(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  status,TResult Function()?  log,TResult Function( PlatformInt64 up,  PlatformInt64 down)?  traffic,TResult Function()?  subscriptions,TResult Function()?  settings,TResult Function()?  coreInfo,TResult Function()?  proxies,TResult Function()?  delays,TResult Function()?  ruleProviders,TResult Function( NoticeLevel kind,  String key,  List<String> args)?  notice,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiEvent_Status() when status != null:
return status();case UiEvent_Log() when log != null:
return log();case UiEvent_Traffic() when traffic != null:
return traffic(_that.up,_that.down);case UiEvent_Subscriptions() when subscriptions != null:
return subscriptions();case UiEvent_Settings() when settings != null:
return settings();case UiEvent_CoreInfo() when coreInfo != null:
return coreInfo();case UiEvent_Proxies() when proxies != null:
return proxies();case UiEvent_Delays() when delays != null:
return delays();case UiEvent_RuleProviders() when ruleProviders != null:
return ruleProviders();case UiEvent_Notice() when notice != null:
return notice(_that.kind,_that.key,_that.args);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  status,required TResult Function()  log,required TResult Function( PlatformInt64 up,  PlatformInt64 down)  traffic,required TResult Function()  subscriptions,required TResult Function()  settings,required TResult Function()  coreInfo,required TResult Function()  proxies,required TResult Function()  delays,required TResult Function()  ruleProviders,required TResult Function( NoticeLevel kind,  String key,  List<String> args)  notice,}) {final _that = this;
switch (_that) {
case UiEvent_Status():
return status();case UiEvent_Log():
return log();case UiEvent_Traffic():
return traffic(_that.up,_that.down);case UiEvent_Subscriptions():
return subscriptions();case UiEvent_Settings():
return settings();case UiEvent_CoreInfo():
return coreInfo();case UiEvent_Proxies():
return proxies();case UiEvent_Delays():
return delays();case UiEvent_RuleProviders():
return ruleProviders();case UiEvent_Notice():
return notice(_that.kind,_that.key,_that.args);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  status,TResult? Function()?  log,TResult? Function( PlatformInt64 up,  PlatformInt64 down)?  traffic,TResult? Function()?  subscriptions,TResult? Function()?  settings,TResult? Function()?  coreInfo,TResult? Function()?  proxies,TResult? Function()?  delays,TResult? Function()?  ruleProviders,TResult? Function( NoticeLevel kind,  String key,  List<String> args)?  notice,}) {final _that = this;
switch (_that) {
case UiEvent_Status() when status != null:
return status();case UiEvent_Log() when log != null:
return log();case UiEvent_Traffic() when traffic != null:
return traffic(_that.up,_that.down);case UiEvent_Subscriptions() when subscriptions != null:
return subscriptions();case UiEvent_Settings() when settings != null:
return settings();case UiEvent_CoreInfo() when coreInfo != null:
return coreInfo();case UiEvent_Proxies() when proxies != null:
return proxies();case UiEvent_Delays() when delays != null:
return delays();case UiEvent_RuleProviders() when ruleProviders != null:
return ruleProviders();case UiEvent_Notice() when notice != null:
return notice(_that.kind,_that.key,_that.args);case _:
  return null;

}
}

}

/// @nodoc


class UiEvent_Status extends UiEvent {
  const UiEvent_Status(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Status);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.status()';
}


}




/// @nodoc


class UiEvent_Log extends UiEvent {
  const UiEvent_Log(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Log);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.log()';
}


}




/// @nodoc


class UiEvent_Traffic extends UiEvent {
  const UiEvent_Traffic({required this.up, required this.down}): super._();
  

 final  PlatformInt64 up;
 final  PlatformInt64 down;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiEvent_TrafficCopyWith<UiEvent_Traffic> get copyWith => _$UiEvent_TrafficCopyWithImpl<UiEvent_Traffic>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Traffic&&(identical(other.up, up) || other.up == up)&&(identical(other.down, down) || other.down == down));
}


@override
int get hashCode {
    return Object.hash(runtimeType,up,down);
}

@override
String toString() {
    return 'UiEvent.traffic(up: $up, down: $down)';
}


}

/// @nodoc
abstract mixin class $UiEvent_TrafficCopyWith<$Res> implements $UiEventCopyWith<$Res> {
  factory $UiEvent_TrafficCopyWith(UiEvent_Traffic value, $Res Function(UiEvent_Traffic) _then) = _$UiEvent_TrafficCopyWithImpl;
@useResult
$Res call({
 PlatformInt64 up, PlatformInt64 down
});




}
/// @nodoc
class _$UiEvent_TrafficCopyWithImpl<$Res>
    implements $UiEvent_TrafficCopyWith<$Res> {
  _$UiEvent_TrafficCopyWithImpl(this._self, this._then);

  final UiEvent_Traffic _self;
  final $Res Function(UiEvent_Traffic) _then;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? up = null,Object? down = null,}) {
  return _then(UiEvent_Traffic(
up: null == up ? _self.up : up // ignore: cast_nullable_to_non_nullable
as PlatformInt64,down: null == down ? _self.down : down // ignore: cast_nullable_to_non_nullable
as PlatformInt64,
  ));
}


}

/// @nodoc


class UiEvent_Subscriptions extends UiEvent {
  const UiEvent_Subscriptions(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Subscriptions);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.subscriptions()';
}


}




/// @nodoc


class UiEvent_Settings extends UiEvent {
  const UiEvent_Settings(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Settings);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.settings()';
}


}




/// @nodoc


class UiEvent_CoreInfo extends UiEvent {
  const UiEvent_CoreInfo(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_CoreInfo);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.coreInfo()';
}


}




/// @nodoc


class UiEvent_Proxies extends UiEvent {
  const UiEvent_Proxies(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Proxies);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.proxies()';
}


}




/// @nodoc


class UiEvent_Delays extends UiEvent {
  const UiEvent_Delays(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Delays);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.delays()';
}


}




/// @nodoc


class UiEvent_RuleProviders extends UiEvent {
  const UiEvent_RuleProviders(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_RuleProviders);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.ruleProviders()';
}


}




/// @nodoc


class UiEvent_Notice extends UiEvent {
  const UiEvent_Notice({required this.kind, required this.key, required  List<String> args}): _args = args,super._();
  

 final  NoticeLevel kind;
 final  String key;
 final  List<String> _args;
 List<String> get args {
  if (_args is EqualUnmodifiableListView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_args);
}


/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiEvent_NoticeCopyWith<UiEvent_Notice> get copyWith => _$UiEvent_NoticeCopyWithImpl<UiEvent_Notice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Notice&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.key, key) || other.key == key)&&const DeepCollectionEquality().equals(other.args, _args));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,key,const DeepCollectionEquality().hash(_args));
}

@override
String toString() {
    return 'UiEvent.notice(kind: $kind, key: $key, args: $args)';
}


}

/// @nodoc
abstract mixin class $UiEvent_NoticeCopyWith<$Res> implements $UiEventCopyWith<$Res> {
  factory $UiEvent_NoticeCopyWith(UiEvent_Notice value, $Res Function(UiEvent_Notice) _then) = _$UiEvent_NoticeCopyWithImpl;
@useResult
$Res call({
 NoticeLevel kind, String key, List<String> args
});




}
/// @nodoc
class _$UiEvent_NoticeCopyWithImpl<$Res>
    implements $UiEvent_NoticeCopyWith<$Res> {
  _$UiEvent_NoticeCopyWithImpl(this._self, this._then);

  final UiEvent_Notice _self;
  final $Res Function(UiEvent_Notice) _then;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? key = null,Object? args = null,}) {
  return _then(UiEvent_Notice(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as NoticeLevel,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
