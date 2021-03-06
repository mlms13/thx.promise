package thx.promise;

import haxe.ds.Option;
using thx.Arrays;
import thx.Error;
import thx.Nil;
using thx.Options;
import thx.Tuple;

class Future<T> {
  public static function sequence(arr : Array<Future<Dynamic>>) : Future<Nil>
    return Future.create(function(callback : Dynamic -> Void) {
        function poll(_ : Dynamic) {
          if(arr.length == 0) {
            callback(nil);
          } else {
            arr.shift().then(poll);
          }
        }
        poll(null);
      });

  public static function afterAll(arr : Array<Future<Dynamic>>) : Future<Nil>
    return Future.create(function(callback)
      all(arr).then(function(_) callback(Nil.nil)));

  public static function all<T>(arr : Array<Future<T>>) : Future<Array<T>>
    return Future.create(function(callback) {
      var results = [],
          counter = 0;
      arr.mapi(function(p, i) {
        p.then(function(value) {
          results[i] = value;
          counter++;
          if(counter == arr.length)
            callback(results);
        });
      });
    });

  public static function create<T>(handler : (T -> Void) -> Void) {
    var future = new Future<T>();
    handler(future.setState);
    return future;
  }

  // inline makes Java behave .... groovy
  inline public static function flatMap<T>(future : Future<Future<T>>) : Future<T>
    return Future.create(function(callback) {
      future.then(function(future) future.then(callback));
    });

  public static function value<T>(v : T)
    return create(function(callback) callback(v));

  var handlers : Array<T -> Void>;
  public var state(default, null) : Option<T>;
  private function new() {
    handlers = [];
    state = None;
  }

#if (js || flash || java)
  inline public function delay(?delayms : Int) {
    if(null == delayms)
      return mapFuture(function(value) return Timer.immediateValue(value));
    else
      return mapFuture(function(value) return Timer.delayValue(value, delayms));
  }
#end

  inline public function hasValue()
    return state.toBool();

  public function map<TOut>(handler : T -> TOut) : Future<TOut>
    return Future.create(function(callback)
      then(function(value)
        callback(handler(value))));

  public function mapAsync<TOut>(handler : T -> (TOut -> Void) -> Void) : Future<TOut>
    return Future.create(function(callback)
      then(function(result : T )
        handler(result, callback)));

  public function mapPromise<TOut>(handler : T -> Promise<TOut>) : Promise<TOut>
    return Promise.create(function(resolve, reject)
      then(function(result : T)
        handler(result)
          .success(resolve)
          .failure(reject)));

  inline public function mapFuture<TOut>(handler : T -> Future<TOut>) : Future<TOut>
    return flatMap(map(handler));

  public function then(handler : T -> Void) {
    handlers.push(handler);
    update();
    return this;
  }

  public function toString() return 'Future';

  function setState(newstate : T) {
    switch state {
      case None:
        state = Some(newstate);
      case Some(r):
        throw new Error('future was already "$r", can\'t apply the new state "$newstate"');
    }
    update();
    return this;
  }

  function update()
    switch state {
      case None:
      case Some(result): {
        var index = -1;
        while(++index < handlers.length)
          handlers[index](result);
        handlers = [];
      }
    };
}

class Futures {
  public static function join<T1,T2>(p1 : Future<T1>, p2 : Future<T2>) : Future<Tuple2<T1,T2>> {
    return Future.create(function(callback) {
      var counter = 0,
          v1 : Null<T1> = null,
          v2 : Null<T2> = null;

      function complete() {
        if(counter < 2)
          return;
        callback(new Tuple2(v1, v2));
      }

      p1.then(function(v) {
        counter++;
        v1 = v;
        complete();
      });

      p2.then(function(v) {
        counter++;
        v2 = v;
        complete();
      });
    });
  }

  public static function log<T>(future : Future<T>, ?prefix : String = '')
    return future.then(
      function(r) trace('$prefix VALUE: $r')
    );
}

class FutureTuple6 {
  public static function mapTuple<T1,T2,T3,T4,T5,T6,TOut>(future : Future<Tuple6<T1,T2,T3,T4,T5,T6>>, callback : T1 -> T2 -> T3 -> T4 -> T5 -> T6 -> TOut) : Future<TOut>
    return future.map(function(t)
      return callback(t._0, t._1, t._2, t._3, t._4, t._5)
    );

  public static function mapTupleAsync<T1,T2,T3,T4,T5,T6,TOut>(future : Future<Tuple6<T1,T2,T3,T4,T5,T6>>, callback : T1 -> T2 -> T3 -> T4 -> T5 -> T6 -> (TOut -> Void) -> Void) : Future<TOut>
    return future.mapAsync(function(t, cb) return callback(t._0, t._1, t._2, t._3, t._4, t._5, cb));

  public static function mapTupleFuture<T1,T2,T3,T4,T5,T6,TOut>(future : Future<Tuple6<T1,T2,T3,T4,T5,T6>>, callback : T1 -> T2 -> T3  -> T4 -> T5 -> T6 -> Future<TOut>) : Future<TOut>
    return future.mapFuture(function(t) return callback(t._0, t._1, t._2, t._3, t._4, t._5));

  public static function tuple<T1,T2,T3,T4,T5,T6>(future : Future<Tuple6<T1,T2,T3,T4,T5,T6>>, callback : T1 -> T2 -> T3 -> T4 -> T5 -> T6 -> Void)
    return future.then(function(t) callback(t._0, t._1, t._2, t._3, t._4, t._5));
}

class FutureTuple5 {
  public static function join<T1,T2,T3,T4,T5,T6>(p1 : Future<Tuple5<T1,T2,T3,T4,T5>>, p2 : Future<T6>) : Future<Tuple6<T1,T2,T3,T4,T5,T6>>
    return Future.create(function(callback)
      Futures.join(p1, p2)
        .then(
          function(t) callback(t._0.with(t._1))));

  public static function mapTuple<T1,T2,T3,T4,T5,TOut>(future : Future<Tuple5<T1,T2,T3,T4,T5>>, callback : T1 -> T2 -> T3 -> T4 -> T5 -> TOut) : Future<TOut>
    return future.map(function(t)
      return callback(t._0, t._1, t._2, t._3, t._4)
    );

  public static function mapTupleAsync<T1,T2,T3,T4,T5,TOut>(future : Future<Tuple5<T1,T2,T3,T4,T5>>, callback : T1 -> T2 -> T3 -> T4 -> T5 -> (TOut -> Void) -> Void) : Future<TOut>
    return future.mapAsync(function(t, cb) return callback(t._0, t._1, t._2, t._3, t._4, cb));

  public static function mapTupleFuture<T1,T2,T3,T4,T5,TOut>(future : Future<Tuple5<T1,T2,T3,T4,T5>>, callback : T1 -> T2 -> T3  -> T4 -> T5 -> Future<TOut>) : Future<TOut>
    return future.mapFuture(function(t) return callback(t._0, t._1, t._2, t._3, t._4));

  public static function tuple<T1,T2,T3,T4,T5>(future : Future<Tuple5<T1,T2,T3,T4,T5>>, callback : T1 -> T2 -> T3 -> T4 -> T5 -> Void)
    return future.then(function(t) callback(t._0, t._1, t._2, t._3, t._4));
}

class FutureTuple4 {
  public static function join<T1,T2,T3,T4,T5>(p1 : Future<Tuple4<T1,T2,T3,T4>>, p2 : Future<T5>) : Future<Tuple5<T1,T2,T3,T4,T5>>
    return Future.create(function(callback)
      Futures.join(p1, p2)
        .then(
          function(t) callback(t._0.with(t._1))));

  public static function mapTuple<T1,T2,T3,T4,TOut>(future : Future<Tuple4<T1,T2,T3,T4>>, callback : T1 -> T2 -> T3 -> T4 -> TOut) : Future<TOut>
    return future.map(function(t)
      return callback(t._0, t._1, t._2, t._3)
    );

  public static function mapTupleAsync<T1,T2,T3,T4,TOut>(future : Future<Tuple4<T1,T2,T3,T4>>, callback : T1 -> T2 -> T3 -> T4 -> (TOut -> Void) -> Void) : Future<TOut>
    return future.mapAsync(function(t, cb) return callback(t._0, t._1, t._2, t._3, cb));

  public static function mapTupleFuture<T1,T2,T3,T4,TOut>(future : Future<Tuple4<T1,T2,T3,T4>>, callback : T1 -> T2 -> T3  -> T4 -> Future<TOut>) : Future<TOut>
    return future.mapFuture(function(t) return callback(t._0, t._1, t._2, t._3));

  public static function tuple<T1,T2,T3,T4>(future : Future<Tuple4<T1,T2,T3,T4>>, callback : T1 -> T2 -> T3 -> T4 -> Void)
    return future.then(function(t) callback(t._0, t._1, t._2, t._3));
}

class FutureTuple3 {
  public static function join<T1,T2,T3,T4>(p1 : Future<Tuple3<T1,T2,T3>>, p2 : Future<T4>) : Future<Tuple4<T1,T2,T3,T4>>
    return Future.create(function(callback)
      Futures.join(p1, p2)
        .then(
          function(t) callback(t._0.with(t._1))));

  public static function mapTuple<T1,T2,T3,TOut>(future : Future<Tuple3<T1,T2,T3>>, callback : T1 -> T2 -> T3 -> TOut) : Future<TOut>
    return future.map(function(t)
      return callback(t._0, t._1, t._2)
    );

  public static function mapTupleAsync<T1,T2,T3,TOut>(future : Future<Tuple3<T1,T2,T3>>, callback : T1 -> T2 -> T3 -> (TOut -> Void) -> Void) : Future<TOut>
    return future.mapAsync(function(t, cb) return callback(t._0, t._1, t._2, cb));

  public static function mapTupleFuture<T1,T2,T3,TOut>(future : Future<Tuple3<T1,T2,T3>>, callback : T1 -> T2 -> T3  -> Future<TOut>) : Future<TOut>
    return future.mapFuture(function(t) return callback(t._0, t._1, t._2));

  public static function tuple<T1,T2,T3>(future : Future<Tuple3<T1,T2,T3>>, callback : T1 -> T2 -> T3 -> Void)
    return future.then(function(t) callback(t._0, t._1, t._2));
}

class FutureTuple2 {
  public static function join<T1,T2,T3>(p1 : Future<Tuple2<T1,T2>>, p2 : Future<T3>) : Future<Tuple3<T1,T2,T3>>
    return Future.create(function(callback)
      Futures.join(p1, p2)
        .then(function(t) callback(t._0.with(t._1))));

  public static function mapTuple<T1,T2,TOut>(future : Future<Tuple2<T1,T2>>, callback : T1 -> T2 -> TOut) : Future<TOut>
    return future.map(function(t) return callback(t._0, t._1));

  public static function mapTupleAsync<T1,T2,TOut>(future : Future<Tuple2<T1,T2>>, callback : T1 -> T2 -> (TOut -> Void) -> Void) : Future<TOut>
    return future.mapAsync(function(t, cb) return callback(t._0, t._1, cb));

  public static function mapTupleFuture<T1,T2,TOut>(future : Future<Tuple2<T1,T2>>, callback : T1 -> T2 -> Future<TOut>) : Future<TOut>
    return future.mapFuture(function(t) return callback(t._0, t._1));

  public static function tuple<T1,T2>(future : Future<Tuple2<T1,T2>>, callback : T1 -> T2 -> Void)
    return future.then(function(t) callback(t._0, t._1));
}

class FutureNil {
  public static function join<T2>(p1 : Future<Nil>, p2 : Future<T2>) : Future<T2>
    return Future.create(function(callback)
      Futures.join(p1, p2)
        .then(function(t) callback(t._1)));

  public static function nil(p : Future<Dynamic>) : Future<Nil>
    return Future.create(function(callback : Nil -> Void)
      p.then(function(_) callback(Nil.nil)));
}