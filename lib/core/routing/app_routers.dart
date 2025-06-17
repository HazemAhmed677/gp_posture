import 'package:camera_stream/core/routing/routes.dart';
import 'package:camera_stream/feature/authentication/presentation/views/sign_in_view.dart'
    show SignInView;
import 'package:camera_stream/feature/home/presentation/ui/camera_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../feature/authentication/presentation/manager/sign_up_with_email_cubit/sign_up_with_email_cubit.dart';
import '../../feature/authentication/presentation/views/sign_up_view.dart';
import '../../feature/switcher/presentation/streaming_view.dart';
import '../../feature/switcher/presentation/switcher_view.dart';
import '../widgets/custom_slider_transition.dart';

abstract class AppRouters {
  static final GoRouter goRouter = GoRouter(
    routes: [
      GoRoute(
        path: Routes.streaming,
        builder: (context, state) => const StreamingView(),
      ),

      // GoRoute(
      //   path: Routes.onBoarding,
      //   pageBuilder: (context, state) => CustomSliderTransition(
      //     key: state.pageKey,
      //     child: const OnboardingView(),
      //     duration: 300,
      //   ),
      // ),
      GoRoute(
        path: Routes.camera,
        pageBuilder: (context, state) => CustomSliderTransition(
          key: state.pageKey,
          child: const CameraScreen(),
          duration: 300,
        ),
      ),
      GoRoute(
        path: Routes.signIn,
        pageBuilder: (context, state) => CustomSliderTransition(
          key: state.pageKey,
          child: const SignInView(),
          duration: 300,
        ),
      ),
      GoRoute(
        path: Routes.signUp,
        pageBuilder: (context, state) => CustomSliderTransition(
          key: state.pageKey,
          child: BlocProvider(
            create: (context) => SignUpWithEmailCubit(),
            child: const SignUpView(),
          ),
          duration: 300,
        ),
      ),
      GoRoute(
        path: Routes.switchView,
        builder: (context, state) => const SwitcherView(),
      ),
    ],
  );
}
