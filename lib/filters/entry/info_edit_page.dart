import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_iconpicker/Models/IconPack.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
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
    var formChildren = [_buildNameEditor(model), _buildIconEditor(model)];
    return FormBuilder(key: widget._formKey, child: Column(children: formChildren));
  }

  Widget _buildNameEditor(FilterModel model) {
    return FormBuilderTextField(
      attribute: 'name',
      decoration: InputDecoration(labelText: 'Name of the filter'),
      initialValue: (model.entityBeingEdited != null) ? model.entityBeingEdited.name : '',
      validators: [FormBuilderValidators.required(errorText: 'Please type a filter name')],
      onChanged: (value) {
        model.entityBeingEdited.name = value;
        print('Model: Entity is now ${model.entityBeingEdited}');
      },
    );
  }

  Widget _buildIconEditor(FilterModel model) {
    return FormBuilderCustomField<IconData>(
      initialValue: (model.entityBeingEdited != null) ? model.entityBeingEdited.icon : null,
      attribute: 'icon',
      validators: [FormBuilderValidators.required(errorText: 'Please select an icon')],
      formField: FormField(builder: (FormFieldState<IconData> field) => _buildIconFormField(model, field)),
    );
  }

  Widget _buildIconFormField(FilterModel model, FormFieldState<IconData> field) {
    return InputDecorator(
      decoration: InputDecoration(labelText: 'Icon for filter selection', errorText: field.errorText),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        Container(),
        (model?.entityBeingEdited?.icon != null) ? Icon(model.entityBeingEdited.icon, size: 50) : Text('No icon set yet', style: TextStyle(backgroundColor: Theme.of(context).primaryColor.withAlpha(50))),
        Container(),
        RaisedButton.icon(
            icon: Icon(Icons.add_circle),
            label: Text('Change Icon'),
            onPressed: () async {
              IconData icon = await FlutterIconPicker.showIconPicker(context, iconPackMode: IconPack.material);
              field.didChange(icon);
              model.entityBeingEdited.icon = icon;
            })
      ]),
    );
  }
}
