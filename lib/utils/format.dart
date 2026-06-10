import 'package:intl/intl.dart';
import '../data/settings.dart';

final _date = DateFormat('yyyy-MM-dd');

NumberFormat _currencyFormat() => NumberFormat.currency(
    locale: 'en_ZA', symbol: AppSettings.instance.currencySymbol);

String money(num v) => _currencyFormat().format(v);
String ymd(DateTime d) => _date.format(d);
