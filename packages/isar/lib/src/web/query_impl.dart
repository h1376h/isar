import 'dart:async';
import 'dart:convert';
import 'dart:js';
import 'dart:typed_data';

import '../../isar.dart';
import 'bindings.dart';

import 'isar_collection_impl.dart';
import 'isar_web.dart';

typedef QueryDeserialize<T> = T Function(Object);

class QueryImpl<T> extends Query<T> {
  QueryImpl(this.col, this.queryJs, this.deserialize, this.propertyName);
  final IsarCollectionImpl<dynamic> col;
  final QueryJs queryJs;
  final QueryDeserialize<T> deserialize;
  final String? propertyName;

  @override
  Isar get isar => col.isar;

  @override
  Future<T?> findFirst() {
    return col.isar.getTxn(false, (IsarTxnJs txn) async {
      final Object? result = await queryJs.findFirst(txn).wait<Object?>();
      if (result == null) {
        return null;
      }
      return deserialize(result);
    });
  }

  @override
  T? findFirstSync() => unsupportedOnWeb();

  @override
  Future<List<T>> findAll() {
    return col.isar.getTxn(false, (IsarTxnJs txn) async {
      final List result = await queryJs.findAll(txn).wait<List<dynamic>>();
      return result.map((e) => deserialize(e as Object)).toList();
    });
  }

  @override
  List<T> findAllSync() => unsupportedOnWeb();

  @override
  Future<R?> aggregate<R>(AggregationOp op) {
    return col.isar.getTxn(false, (IsarTxnJs txn) async {
      final String property = propertyName ?? col.schema.idName;

      num? result;
      switch (op) {
        case AggregationOp.min:
          result = await queryJs.min(txn, property).wait();
          break;
        case AggregationOp.max:
          result = await queryJs.max(txn, property).wait();
          break;
        case AggregationOp.sum:
          result = await queryJs.sum(txn, property).wait();
          break;
        case AggregationOp.average:
          result = await queryJs.average(txn, property).wait();
          break;
        case AggregationOp.count:
          result = await queryJs.count(txn).wait();
          break;
      }

      if (result == null) {
        return null;
      }

      if (R == DateTime) {
        return DateTime.fromMillisecondsSinceEpoch(result.toInt()).toLocal()
            as R;
      } else if (R == int) {
        return result.toInt() as R;
      } else if (R == double) {
        return result.toDouble() as R;
      } else {
        return null;
      }
    });
  }

  @override
  R? aggregateSync<R>(AggregationOp op) => unsupportedOnWeb();

  @override
  Future<bool> deleteFirst() {
    return col.isar.getTxn(true, (IsarTxnJs txn) {
      return queryJs.deleteFirst(txn).wait();
    });
  }

  @override
  bool deleteFirstSync() => unsupportedOnWeb();

  @override
  Future<int> deleteAll() {
    return col.isar.getTxn(true, (IsarTxnJs txn) {
      return queryJs.deleteAll(txn).wait();
    });
  }

  @override
  int deleteAllSync() => unsupportedOnWeb();

  @override
  Stream<List<T>> watch({bool initialReturn = false}) {
    JsFunction? stop;
    final StreamController<List<T>> controller =
        StreamController<List<T>>(onCancel: () {
      stop?.apply([]);
    });

    if (initialReturn) {
      findAll().then((List<T> results) {
        controller.add(results);
      });
    }

    final Null Function(List results) callback =
        allowInterop((List<dynamic> results) {
      controller.add(results.map((e) => deserialize(e as Object)).toList());
    });
    stop = col.native.watchQuery(queryJs, callback);

    return controller.stream;
  }

  @override
  Stream<void> watchLazy() {
    JsFunction? stop;
    final StreamController<void> controller =
        StreamController<void>(onCancel: () {
      stop?.apply([]);
    });

    final Null Function() callback = allowInterop(() {
      controller.add(null);
    });
    stop = col.native.watchQueryLazy(queryJs, callback);

    return controller.stream;
  }

  @override
  Future<R> exportJsonRaw<R>(R Function(Uint8List) callback) async {
    return col.isar.getTxn(false, (IsarTxnJs txn) async {
      final result = await queryJs.findAll(txn).wait<dynamic>();
      final String jsonStr = stringify(result);
      return callback(const Utf8Encoder().convert(jsonStr));
    });
  }

  @override
  Future<List<Map<String, dynamic>>> exportJson() {
    return col.isar.getTxn(false, (IsarTxnJs txn) async {
      final List result = await queryJs.findAll(txn).wait<List<dynamic>>();
      return result.map((e) => jsMapToDart(e as Object)).toList();
    });
  }

  @override
  R exportJsonRawSync<R>(R Function(Uint8List) callback) => unsupportedOnWeb();

  @override
  List<Map<String, dynamic>> exportJsonSync({bool primitiveNull = true}) =>
      unsupportedOnWeb();
}
