import 'dart:js_util';
import 'dart:typed_data';

import 'package:isar/isar.dart';
import 'package:isar/src/isar_native_interface.dart';
import 'package:isar/src/web/isar_link_impl.dart';
import 'package:js/js.dart';
import 'package:meta/meta.dart';

import 'open.dart';

const isarMinId = -9007199254740991;
const isarMaxId = 9007199254740991;
const isarAutoIncrementId = double.negativeInfinity;

Never unsupportedOnWeb() {
  throw UnsupportedError('This operation is not supported for Isar web');
}

/// @nodoc
@protected
typedef IsarRawObject = dynamic;

/// @nodoc
@protected
typedef IsarBytePointer = dynamic;

/// @nodoc
@protected
typedef IsarBinaryReader = dynamic;

/// @nodoc
@protected
// ignore: constant_identifier_names
const dynamic IsarBinaryWriter = null;

class _IsarWeb implements IsarNativeInterface {
  const _IsarWeb();

  @override
  Uint8List bufAsBytes(IsarBytePointer pointer, int length) {
    throw UnimplementedError();
  }

  @override
  void initializeLibraries({Map<String, String> libraries = const {}}) {
    throw UnimplementedError();
  }

  @override
  dynamic jsObjectGet(Object o, Object key) {
    return getProperty(o, key);
  }

  @override
  void jsObjectSet(Object o, Object key, dynamic value) {
    setProperty(o, key, value);
  }

  @override
  dynamic newJsObject() {
    return newObject();
  }

  @override
  IsarLink<OBJ> newLink<OBJ>() {
    return IsarLinkImpl();
  }

  @override
  IsarLinks<OBJ> newLinks<OBJ>() {
    return IsarLinksImpl();
  }

  @override
  Future<Isar> open({
    required String directory,
    required String name,
    required bool relaxedDurability,
    required List<CollectionSchema> schemas,
  }) {
    return openIsar(
      name: name,
      directory: directory,
      relaxedDurability: relaxedDurability,
      schemas: schemas,
    );
  }

  @override
  Isar openSync({
    required String directory,
    required String name,
    required bool relaxedDurability,
    required List<CollectionSchema> schemas,
  }) =>
      unsupportedOnWeb();

  @override
  List<String> splitWords(String value) {
    throw UnimplementedError();
  }
}

/// @nodoc
@protected
// ignore: constant_identifier_names
const IsarNative = _IsarWeb();