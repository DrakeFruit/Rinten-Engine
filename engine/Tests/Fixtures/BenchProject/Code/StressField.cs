using System;

namespace BenchProject;

//Fills a square grid of model cubes at runtime. The scene file then only names the component and how many cubes it
//wants, so the fixture stays small and the same code makes the 1k, 10k and 100k scenes - see scenes.sh's core set.
public sealed class StressField : Component
{
	//Cubes to make. The grid is ceil(sqrt(Count)) on a side, centred on this object.
	[Property] public int Count { get; set; } = 10_000;

	//Metres between neighbours.
	[Property] public float Spacing { get; set; } = 2.0f;

	//Mark every cube static, which lets rendering merge and cache them the way it would a real level.
	[Property] public bool Static { get; set; } = true;

	//Whether the cubes cast shadows.
	[Property] public bool Shadows { get; set; } = true;

	protected override void OnStart()
	{
		var count = Math.Max( 0, Count );
		if ( count == 0 ) return;

		var side = (int)MathF.Ceiling( MathF.Sqrt( count ) );
		var half = ( side - 1 ) * Spacing * 0.5f;

		for ( var i = 0; i < count; i++ )
		{
			//The component's own scene rather than Game.ActiveScene, which can still be the editor's at this point.
			var go = Scene.CreateObject( true );
			go.Name = $"Cube {i}";

			go.WorldPosition = WorldPosition + new Vector3(
				(i % side) * Spacing - half,
				0.0f,
				(i / side) * Spacing - half );

			if ( Static ) go.Flags |= GameObjectFlags.Static;

			var renderer = go.Components.Create<ModelRenderer>();
			renderer.Model = Model.Cube;

			if ( !Shadows ) renderer.RenderType = ModelRenderer.ShadowRenderType.Off;
		}
	}
}
