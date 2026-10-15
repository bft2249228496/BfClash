import 'package:bfclash/common/context.dart';
import 'package:bfclash/views/config/general.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

class ConfigView extends StatelessWidget {
  const ConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: context.appLocalizations.basicConfig,
      body: const GeneralListView(),
    );
  }
}
