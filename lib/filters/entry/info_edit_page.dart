import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:photofilters/filters/filter_model.dart';
import 'package:scoped_model/scoped_model.dart';

import '../filter_model.dart';

class InfoEditPage extends StatefulWidget {
  final GlobalKey<FormBuilderState> _formKey;

  InfoEditPage(this._formKey);

  @override
  State<StatefulWidget> createState() => InfoEditPageState();
}

class InfoEditPageState extends State<InfoEditPage> {
  @override
  Widget build(BuildContext context) => ScopedModelDescendant<FilterModel>(builder: (BuildContext context, Widget child, FilterModel model) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: _buildForm(context, model),
        );
      });

  Widget _buildForm(BuildContext context, FilterModel model) {
    var formChildren = [_buildNameEditor(model)];
    return FormBuilder(key: widget._formKey, child: Column(children: formChildren));
  }

  Widget _buildNameEditor(FilterModel model) {
    return FormBuilderTextField(
      attribute: 'name',
      decoration: InputDecoration(labelText: 'Name of the filter'),
      initialValue: (model.entityBeingEdited != null) ? model.entityBeingEdited.name : '',
      validators: [FormBuilderValidators.required()],
      onChanged: (value) {
        model.entityBeingEdited.name = value;
        print('Model: Entity is now ${model.entityBeingEdited}');
      },
    );
  }
}
