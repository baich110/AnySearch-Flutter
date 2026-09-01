import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../viewmodels/search_viewmodel.dart';
import 'screens/home_screen.dart';
import 'screens/results_screen.dart';
import 'screens/reading_screen.dart';
import 'screens/about_screen.dart';
import 'screens/history_screen.dart';
import 'screens/browser_screen.dart';

class AnySearchApp extends StatelessWidget {
  const AnySearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SearchViewModel>(
          create: (_) => SearchViewModel(ApiService())..init(),
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
          useSystemColors: true,
          appBarTheme: const AppBarTheme(centerTitle: false),
        ),
        home: const _AppShell(),
      ),
    );
  }
}

/// 根组件：隐私协议弹窗 + 应用主界面 + 全局无障碍实时播报区
class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();

    final content = !vm.privacyAgreed
        ? PrivacyAgreementDialog(
            onAgree: vm.agreeToPrivacy,
          )
        : const _AppScaffold();

    return Stack(
      children: [
        content,
        // 全局实时播报：异步状态（搜索/提取/翻译/错误等）自动播报
        // Web 映射 aria-live，安卓 TalkBack / Windows NVDA 同样生效
        _StatusLiveRegion(message: vm.statusMessage),
      ],
    );
  }
}

/// 全局无障碍实时播报区：内容变化时由读屏自动播报
class _StatusLiveRegion extends StatelessWidget {
  final String message;
  const _StatusLiveRegion({required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: SizedBox(
          width: 1,
          height: 1,
          child: Text(message,
            style: const TextStyle(fontSize: 1, color: Colors.transparent)),
        ),
      ),
    );
  }
}

/// 主界面：侧边栏（历史/关于/设置）+ 路由
class _AppScaffold extends StatelessWidget {
  const _AppScaffold();

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: const Text('搜索', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: '打开菜单',
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: _AppDrawer(scaffoldKey: scaffoldKey),
      body: _AppRouter(
        onOpenDrawer: () => scaffoldKey.currentState?.openDrawer(),
      ),
    );
  }
}

/// 侧边栏菜单：历史记录 / 关于 / 设置
class _AppDrawer extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const _AppDrawer({required this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();

    return Drawer(
      width: 280,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Semantics(
                header: true,
                child: Text('搜索 · 菜单',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('历史记录'),
              onTap: () {
                Navigator.pop(context);
                vm.showHistory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('关于'),
              onTap: () {
                Navigator.pop(context);
                vm.showAbout();
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Semantics(
                header: true,
                child: Text('设置',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold)),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.link),
              title: const Text('阅读页带链接渲染'),
              subtitle: Text(vm.renderLinks
                ? '当前：带链接（每链接有提取/打开操作）'
                : '当前：纯文本（更简洁稳定）'),
              value: vm.renderLinks,
              onChanged: vm.setRenderLinksPreference,
            ),
          ],
        ),
      ),
    );
  }
}

/// 根据 ViewModel 状态路由到不同页面
class _AppRouter extends StatelessWidget {
  final VoidCallback onOpenDrawer;
  const _AppRouter({required this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();

    final screen = switch (vm.state) {
      UiStateIdle() => HomeScreen(onOpenDrawer: onOpenDrawer),
      UiStateLoading() => const _LoadingView(),
      UiStateResults() => const ResultsScreen(),
      UiStateExtracting() => _ExtractingView(url: (vm.state as UiStateExtracting).url),
      UiStateReading() => const ReadingScreen(),
      UiStateError() => _ErrorView(
          message: (vm.state as UiStateError).message,
        ),
      UiStateAbout() => const AboutScreen(),
      UiStateHistory() => const HistoryScreen(),
      UiStateBrowsing() => BrowserScreen(
          url: (vm.state as UiStateBrowsing).url,
        ),
    };

    // 屏幕切换时把读屏/键盘焦点移到新屏幕，避免焦点悬空
    return _ScreenFocusScope(
      key: ValueKey('screen-${vm.state.runtimeType}'),
      child: screen,
    );
  }
}

/// 屏幕切换时把焦点移入新屏幕的焦点作用域
class _ScreenFocusScope extends StatefulWidget {
  final Widget child;
  const _ScreenFocusScope({super.key, required this.child});

  @override
  State<_ScreenFocusScope> createState() => _ScreenFocusScopeState();
}

class _ScreenFocusScopeState extends State<_ScreenFocusScope> {
  final FocusScopeNode _node = FocusScopeNode(debugLabel: 'screen-scope');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _node.requestFocus();
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(node: _node, child: widget.child);
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Semantics(
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

/// 隐私协议弹窗
class PrivacyAgreementDialog extends StatelessWidget {
  final VoidCallback onAgree;
  const PrivacyAgreementDialog({required this.onAgree});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text('隐私政策与用户协议',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  const Text('''欢迎使用 AnySearch。

AnySearch 不收集任何个人信息，无广告、无追踪 SDK。
- 搜索请求发送至 AnySearch MCP 后端
- 翻译数据发送至腾讯 TranSmart 接口
- 提取的网页内容归原网站所有

使用本应用即表示你同意上述条款。'''),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onAgree,
                        child: const Text('同意并继续'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}