using System;

namespace BenchProject;

//Drops a grid of physics boxes onto a static floor, all made at runtime. The floor is the component's own so the scene
//file stays a single object, and so the boxes always have something to land on.
public sealed class PhysicsField : Component
{
	//Boxes to drop. The grid is ceil(sqrt(Count)) on a side, centred on this object.
	[Property] public int Count { get; set; } = 1_000;

	//Metres between neighbours.
	[Property] public float Spacing { get; set; } = 2.0f;

	//Height the boxes start at, above the floor.
	[Property] public float DropHeight { get; set; } = 6.0f;

	//Whether the boxes are drawn as well as simulated.
	[Property] public bool Render { get; set; } = true;

	protected override void OnStart()
	{
		var count = Math.Max( 0, Count );
		var side = Math.Max( 1, (int)MathF.Ceiling( MathF.Sqrt( count ) ) );
		var half = ( side - 1 ) * Spacing * 0.5f;

		MakeFloor( side * Spacing );

		for ( var i = 0; i < count; i++ )
		{
			//The component's own scene rather than Game.ActiveScene, which can still be the editor's at this point.
			var go = Scene.CreateObject( true );
			go.Name = $"Box {i}";

			go.WorldPosition = WorldPosition + new Vector3(
				(i % side) * Spacing - half,
				DropHeight,
				(i / side) * Spacing - half );

			go.Components.Create<BoxCollider>();
			go.Components.Create<Rigidbody>();

			if ( Render )
			{
				var renderer = go.Components.Create<ModelRenderer>();
				renderer.Model = Model.Cube;
			}
		}
	}

	private void MakeFloor( float width )
	{
		var size = MathF.Max( width + Spacing * 2.0f, 10.0f );

		var floor = Scene.CreateObject( true );
		floor.Name = "Floor";
		floor.WorldPosition = WorldPosition + new Vector3( 0.0f, -1.0f, 0.0f );
		floor.Flags |= GameObjectFlags.Static;

		//The scale goes on before the collider exists, so the shape is built at the floor's real size rather than
		//relying on a later transform change to rebuild it.
		floor.WorldScale = new Vector3( size, 1.0f, size );

		//The collider's own size stays a metre cube: a box collider multiplies its size by the object's world scale,
		//so scaling the object is the one place the floor's size is written down. Setting both made it size squared.
		floor.Components.Create<BoxCollider>();

		var renderer = floor.Components.Create<ModelRenderer>();
		renderer.Model = Model.Cube;
		renderer.RenderType = ModelRenderer.ShadowRenderType.Off;
	}
}
