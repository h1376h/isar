// ignore_for_file: avoid_print

part of isar;

// ignore: avoid_classes_with_only_static_members
abstract class _IsarConnect {
  static const Map<ConnectAction, Future Function(Map<String, dynamic> _)>
      _handlers = {
    ConnectAction.getVersion: _getVersion,
    ConnectAction.getSchema: _getSchema,
    ConnectAction.listInstances: _listInstances,
    ConnectAction.watchInstance: _watchInstance,
    ConnectAction.executeQuery: _executeQuery,
    ConnectAction.removeQuery: _removeQuery,
  };

  static bool _initialized = false;
  // ignore: cancel_subscriptions
  static StreamSubscription<void>? _querySubscription;
  static final List<StreamSubscription<void>> _collectionSubscriptions =
      <StreamSubscription<void>>[];

  static void initialize() {
    if (_initialized) {
      return;
    }
    _initialized = true;

    Isar.addOpenListener((_) {
      postEvent(ConnectEvent.instancesChanged.event, {});
    });

    Isar.addCloseListener((_) {
      postEvent(ConnectEvent.instancesChanged.event, {});
    });

    for (final MapEntry<ConnectAction,
        Future Function(Map<String, dynamic> _)> handler in _handlers.entries) {
      registerExtension(handler.key.method,
          (String method, Map<String, String> parameters) async {
        try {
          final Map<String, dynamic> args = parameters.containsKey('args')
              ? jsonDecode(parameters['args']!) as Map<String, dynamic>
              : <String, dynamic>{};
          final Map<String, dynamic> result = {
            'result': await handler.value(args)
          };
          return ServiceExtensionResponse.result(jsonEncode(result));
        } catch (e) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.extensionError,
            e.toString(),
          );
        }
      });
    }

    _printConnection();
  }

  static void _printConnection() {
    Service.getInfo().then((ServiceProtocolInfo info) {
      final Uri? serviceUri = info.serverUri;
      if (serviceUri == null) {
        return;
      }
      final int port = serviceUri.port;
      String path = serviceUri.path;
      if (path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      if (path.endsWith('=')) {
        path = path.substring(0, path.length - 1);
      }
      print('╔══════════════════════════════════════════════╗');
      print('║             ISAR CONNECT STARTED             ║');
      print('╟──────────────────────────────────────────────╢');
      print('║ Open the link in Chrome to connect to the    ║');
      print('║ Isar Inspector while this build is running.  ║');
      print('╟──────────────────────────────────────────────╢');
      print('║ https://inspect.isar.dev/#/$port$path ║');
      print('╚══════════════════════════════════════════════╝');
    });
  }

  static Future<dynamic> _getVersion(Map<String, dynamic> _) async {
    return isarCoreVersion;
  }

  static Future<dynamic> _getSchema(Map<String, dynamic> _) async {
    return jsonDecode(Isar.schema!);
  }

  static Future<dynamic> _listInstances(Map<String, dynamic> _) async {
    return Isar.instanceNames.toList();
  }

  static Future<bool> _watchInstance(Map<String, dynamic> params) async {
    for (final StreamSubscription<void> sub in _collectionSubscriptions) {
      unawaited(sub.cancel());
    }

    _collectionSubscriptions.clear();
    if (params.isEmpty) {
      return true;
    }

    final String instanceName = params['instance'] as String;
    final Isar instance = Isar.getInstance(instanceName)!;

    for (final IsarCollection collection in instance._collections.values) {
      _sendCollectionInfo(collection);
      final StreamSubscription<void> sub = collection.watchLazy().listen((_) {
        _sendCollectionInfo(collection);
      });
      _collectionSubscriptions.add(sub);
    }

    return true;
  }

  static void _sendCollectionInfo(IsarCollection<dynamic> collection) {
    final int count = collection.countSync();
    final int size = collection.getSizeSync(
      includeIndexes: true,
      includeLinks: true,
    );
    final ConnectCollectionInfo collectionInfo = ConnectCollectionInfo(
      instance: collection.isar.name,
      collection: collection.name,
      size: size,
      count: count,
    );
    postEvent(
      ConnectEvent.collectionInfoChanged.event,
      collectionInfo.toJson(),
    );
  }

  static Future<List<Map<String, dynamic>>> _executeQuery(
      Map<String, dynamic> params) async {
    if (_querySubscription != null) {
      unawaited(_querySubscription!.cancel());
    }
    _querySubscription = null;
    if (params.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final Query query = _getQuery(params);

    final Stream<void> stream = query.watchLazy();
    _querySubscription = stream.listen((event) {
      postEvent(ConnectEvent.queryChanged.event, {});
    });

    return query.exportJson();
  }

  static Future<bool> _removeQuery(Map<String, dynamic> params) async {
    final Query query = _getQuery(params);
    await query.isar.writeTxn(query.deleteAll);
    return true;
  }

  static Query<dynamic> _getQuery(Map<String, dynamic> params) {
    final ConnectQuery query = ConnectQuery.fromJson(params);
    final IsarCollection collection = Isar.getInstance(query.instance)!
        .getCollectionByNameInternal(query.collection)!;
    WhereClause? whereClause;
    Sort whereSort = Sort.asc;
    SortProperty? sortProperty;

    final SortProperty? qSort = query.sortProperty;
    if (qSort != null) {
      if (qSort.property == collection.idName) {
        whereClause = const IdWhereClause.any();
        whereSort = qSort.sort;
      } else {
        sortProperty = qSort;
      }
    }
    return collection.buildQuery(
      whereClauses: [if (whereClause != null) whereClause],
      whereSort: whereSort,
      filter: query.filter,
      offset: query.offset,
      limit: query.limit,
      sortBy: [if (sortProperty != null) sortProperty],
    );
  }
}
