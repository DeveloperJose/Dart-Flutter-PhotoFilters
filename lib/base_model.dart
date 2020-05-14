import 'package:scoped_model/scoped_model.dart';

/// The base model for all scoped models of this app
/// Keeps track of a stack index so it can be used with an IndexedStack
class BaseModel<T> extends Model {
  int stackIndex = 0;
  List<T> entityList = [];
  T entityBeingEdited;

  void setStackIndex(int stackIndex) {
    this.stackIndex = stackIndex;
    notifyListeners();
  }

  void loadData(database) async {
    entityList.clear();
    entityList.addAll(await database.getAll());
    notifyListeners();
  }

  void triggerRebuild() {
    notifyListeners();
  }
}
