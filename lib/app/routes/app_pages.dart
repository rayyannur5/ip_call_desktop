import 'package:get/get.dart';
import '../views/home/home_view.dart';
import '../bindings/app_binding.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: AppBinding(),
    ),
  ];
}
