import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton 占位组件,跨页面复用。
/// 用法:
///   if (_loading) return const NodesSkeleton();
///   return realContent;
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 把内容包一层 shimmer 流光效果。所有 SkeletonBox 子组件颜色由 shimmer 控制。
class SkeletonShimmer extends StatelessWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB),
      highlightColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF3F4F6),
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// 通用列表骨架(竖向 N 行卡片,适合大多数列表型页面)
class ListSkeleton extends StatelessWidget {
  final int rows;
  final double rowHeight;
  final double horizontalPadding;
  const ListSkeleton({
    super.key,
    this.rows = 6,
    this.rowHeight = 72,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
        itemCount: rows,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => SkeletonBox(height: rowHeight, radius: 12),
      ),
    );
  }
}

/// 节点列表专用骨架(每行带左侧圆形 icon + 右侧文本块 + 末尾延迟数字)
class NodesSkeleton extends StatelessWidget {
  const NodesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(width: 36, height: 36, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonBox(width: 140, height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(width: 90, height: 11),
                  ],
                ),
              ),
              const SkeletonBox(width: 48, height: 18, radius: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// 套餐 / 流量包样式骨架(高一些的卡片,左标题+价格+按钮区)
class PlanCardsSkeleton extends StatelessWidget {
  const PlanCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 160, height: 16),
              SkeletonBox(width: 220, height: 11),
              SkeletonBox(width: 120, height: 22, radius: 11),
            ],
          ),
        ),
      ),
    );
  }
}

/// 表格 / 订单样式(行少 + 简洁)
class TableRowsSkeleton extends StatelessWidget {
  final int rows;
  const TableRowsSkeleton({super.key, this.rows = 5});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: rows,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: const Row(
            children: [
              SkeletonBox(width: 100, height: 13),
              Spacer(),
              SkeletonBox(width: 60, height: 13),
            ],
          ),
        ),
      ),
    );
  }
}

/// 仪表盘(首屏)骨架 — 上方大卡 + 流量条 + 几个统计块
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: const [
          SkeletonBox(width: double.infinity, height: 130, radius: 16),
          SizedBox(height: 14),
          SkeletonBox(width: 200, height: 14),
          SizedBox(height: 10),
          SkeletonBox(width: double.infinity, height: 80, radius: 12),
          SizedBox(height: 20),
          Row(children: [
            Expanded(child: SkeletonBox(height: 90, radius: 12)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 90, radius: 12)),
          ]),
          SizedBox(height: 12),
          SkeletonBox(width: double.infinity, height: 56, radius: 12),
        ],
      ),
    );
  }
}
