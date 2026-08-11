import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../viewmodels/search_viewmodel.dart';
import 'screens/home_screen.dart';
import 'screens/results_screen.dart';
import 'screens/reading_screen.dart';
import 'screens/about_screen.dart';

class AnySearchApp extends StatelessWidget {
  const AnySearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SearchViewModel>(
          create: (_) => SearchViewModel(ApiService())..loadVerticals(),
        ),
      ],
      child: MaterialApp(
        title: '搜索',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
          ),
          // 高对比度模式支持
          useSystemColors: true,
          appBarTheme: const AppBarTheme(centerTitle: false),
        ),
        // 无障碍：语义调试开关（发布时关闭）
        showSemanticsDebugger: false,
        home: const _AppRouter(),
      ),
    );
  }
}

/// 根据 ViewModel 状态路由到不同页面
class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();

    return switch (vm.state) {
      UiStateIdle() => const HomeScreen(),
      UiStateLoading() => const _LoadingView(),
      UiStateResults() => const ResultsScreen(),
      UiStateExtracting() => _ExtractingView(url: (vm.state as UiStateExtracting).url),
      UiStateReading() => const ReadingScreen(),
      UiStateError() => _ErrorView(
          message: (vm.state as UiStateError).message,
        ),
      UiStateAbout() => const AboutScreen(),
    };
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Semantics(
        liveRegion: true,
        label: '正在搜索，请稍候',
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('搜索中...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtractingView extends StatelessWidget {
  final String url;
  const _ExtractingView({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Semantics(
        liveRegion: true,
        label: '正在提取正文内容，请稍候',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('正在提取正文...'),
              const SizedBox(height: 4),
              Text(
                url,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<SearchViewModel>();
    return Scaffold(
      body: Semantics(
        liveRegion: true,
        label: '错误: $message',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: vm.backToResults,
                    child: const Text('返回'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: vm.search,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
