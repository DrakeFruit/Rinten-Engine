using BenchmarkDotNet.Configs;
using BenchmarkDotNet.Jobs;
using BenchmarkDotNet.Running;

public class Program
{
	//The scene and physics benches are quick to run by hand; a short job keeps a check to a minute or two.
	private static IConfig ShortConfig => ManualConfig
			.Create( DefaultConfig.Instance )
			.WithOptions( ConfigOptions.JoinSummary | ConfigOptions.DisableLogFile )
			.AddJob( Job.ShortRun );

	public static void Main( string[] args )
	{
		var config = ManualConfig
				.Create( DefaultConfig.Instance )
				.WithOptions( ConfigOptions.JoinSummary | ConfigOptions.DisableLogFile | ConfigOptions.LogBuildOutput )
				.AddJob( Job.MediumRun );

		if ( args.Length > 0 && args[0] == "layout" )
		{
			BenchmarkRunner.Run<Benchmarks.Layout.LayoutBenchmarks>( Benchmarks.Layout.LayoutBenchmarks.Config );
			return;
		}

		if ( args.Length > 0 && args[0] == "gizmo" )
		{
			Benchmarks.Collider.ModelColliderGizmoBenchmarks.Run( [50_000, 250_000, 1_000_000] );
			return;
		}

		if ( args.Length > 1 && args[0] == "catalog" )
		{
			Benchmarks.Assets.ImportCatalogBenchmarks.Run( args[1] );
			return;
		}

		if ( args.Length > 0 && args[0] == "scene" )
		{
			BenchmarkRunner.Run<Benchmarks.Scenes.GameObjectBenchmarks>( ShortConfig );
			return;
		}

		if ( args.Length > 0 && args[0] == "components" )
		{
			BenchmarkRunner.Run<Benchmarks.Scenes.ComponentBenchmarks>( ShortConfig );
			return;
		}

		if ( args.Length > 0 && args[0] == "physics" )
		{
			BenchmarkRunner.Run<Benchmarks.Physics.PhysicsBenchmarks>( ShortConfig );
			return;
		}

		//BenchmarkRunner.Run<StringtHashSet>( config );
		//BenchmarkRunner.Run<MemoryAlloc>( config );
		//BenchmarkRunner.Run<StringHashing>( config );
		BenchmarkRunner.Run<ByteStreamTest>( config );

		//BenchmarkRunner.Run( typeof( Program ).Assembly, config );
	}
}
