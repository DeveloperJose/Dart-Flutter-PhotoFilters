import 'package:scoped_model/scoped_model.dart';

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