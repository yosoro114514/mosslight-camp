extends RefCounted

const Evolution = preload("res://scripts/evolution.gd")
const HIT_TIME := 0.36
const POSE_TIME := 0.38
const EMBER := Color("#ff9d42")
const ICE := Color("#ffc1de")
const WIND := Color("#68efdb")
const SPARK := Color("#fff5bb")

static func travel_fraction(owl: bool, power: bool) -> float:
	if owl:
		return 0.18
	return 0.19 if power else 0.28

# Transform only the portrait. The base and level badge stay on their tile.
static func pose(g, cell: int) -> Transform2D:
	if not g.attack_poses.has(cell) or g.forms[cell] < Evolution.Form.POWER:
		return Transform2D.IDENTITY
	var action: Dictionary = g.attack_poses[cell]
	var t := clampf((g.elapsed - float(action.start)) / POSE_TIME, 0, 1)
	if t >= 1:
		return Transform2D.IDENTITY
	var aim: Vector2 = action.aim
	var side := 1.0 if aim.x >= 0 else -1.0
	var tilt: float
	var offset: Vector2
	var squash: float
	if g.forms[cell] == Evolution.Form.POWER:
		# Hold the strike for a few frames, then recoil and settle.
		var hit := 1.0 - smoothstep(0.15,0.45,t)
		var recoil := sin(PI * clampf((t-0.23)/0.77,0,1))
		offset = aim * (9.0*hit - 5.0*recoil)
		tilt = side * (0.16*hit - 0.13*recoil)
		squash = 0.16*hit - 0.07*recoil
		match g.allies[cell]:
			g.Ally.HARE: offset = Vector2(0,6*hit - 8*recoil)
			g.Ally.OWL: offset = Vector2(0,-8*hit + 3*recoil)
			g.Ally.HEDGEHOG: offset = -aim * (10*hit - 3*recoil)
	else:
		var sweep := sin(t*TAU) * (1.0-t)
		var lift := sin(t*PI)
		tilt = side * 0.27*sweep
		offset = Vector2(4*side*sweep,-6*lift)
		squash = -0.09*lift
		if g.allies[cell] == g.Ally.OWL:
			offset.y -= 5*lift
		elif g.allies[cell] == g.Ally.HEDGEHOG:
			offset += -aim * 4*sweep
	return Transform2D(tilt,Vector2(1+squash,1-squash),0,offset)

static func shard(n: CanvasItem, tip: Vector2, tail: Vector2, width: float, color: Color) -> void:
	var axis := tail.direction_to(tip)
	if axis == Vector2.ZERO:
		return
	var base := tail.lerp(tip,0.32)
	var flank := axis.orthogonal() * width
	n.draw_colored_polygon(PackedVector2Array([tip,base+flank,tail,base-flank]),color)

static func impact(n: CanvasItem, point: Vector2, axis: Vector2, age: float, color: Color, size: float) -> void:
	var alpha := 1.0-age
	var spread := size * (0.30+0.70*sin(age*PI/2))
	for i in 6:
		var ray := axis.rotated(i*TAU/6)
		var length := spread * (1.0 if i%2==0 else 0.63)
		shard(n,point+ray*length,point+ray*length*age,3.1*alpha,Color(color,alpha))
	n.draw_circle(point,1.5+5.5*alpha,Color(SPARK,alpha),true,-1,true)

static func frost_pulse(n: CanvasItem, event: Dictionary) -> void:
	var age := 0.46 - float(event.life)
	var alpha := clampf(event.life/0.46,0,1)
	var center: Vector2 = event.from
	var power: bool = event.form == Evolution.Form.POWER
	var radius := lerpf(12,event.reach,clampf(age/(0.13 if power else 0.30),0,1))
	if power:
		n.draw_arc(center,radius,0,TAU,80,Color(ICE,0.58*alpha),1.0+5.0*alpha,true)
		return
	n.draw_arc(center,radius,0,TAU,96,Color(WIND,alpha),3,true)
	n.draw_arc(center,maxf(4,radius-9),0,TAU,96,Color(WIND,0.38*alpha),2,true)
	for i in 12:
		var axis := Vector2.from_angle(i*TAU/12)
		shard(n,center+axis*(radius+3),center+axis*maxf(1,radius-14),3,Color(Color.WHITE,alpha))

static func draw_hit(n: CanvasItem, g, event: Dictionary) -> void:
	var age := 1.0-float(event.life)/HIT_TIME
	if event.has("echo") and age < 0.20:
		var size: float = event.echo_size
		var top_left: Vector2 = event.to + Vector2(-size/2, 9-size-event.echo_lift)
		var opacity := 0.62*(1.0-clampf(age/0.20,0,1))
		n.draw_texture_rect(event.echo,Rect2(top_left,Vector2.ONE*size),false,Color(0.80,0.98,1,opacity))
	if age <= 0 or age >= 1:
		return
	var power: bool = event.form == Evolution.Form.POWER
	var origin: Vector2 = event.from
	var end: Vector2 = event.to + Vector2(0,-10)
	if event.hop > 0:
		origin += Vector2(0,-10)
	var axis := origin.direction_to(end)
	if axis == Vector2.ZERO:
		axis = Vector2.RIGHT
	var alpha := 1.0-age
	match event.kind:
		g.Ally.FOX:
			if power:
				var cut := axis.rotated(0.72)
				shard(n,end+cut*(15+18*age),end-cut*23,6*alpha,Color(EMBER,alpha))
				impact(n,end,cut,age,EMBER,26)
			else:
				var radius := origin.distance_to(end)
				var angle := axis.angle()
				n.draw_arc(origin,maxf(1,radius),angle-0.42,angle+age*0.5,18,Color(WIND,alpha),3,true)
				var tangent := axis.orthogonal()
				shard(n,end+tangent*(4+18*age),end-tangent*8,4*alpha,Color(WIND,alpha))
		g.Ally.HARE:
			if power:
				# Crystal punches up from the hit point, then splinters.
				var height := 28.0*(1-smoothstep(0.42,1,age))
				shard(n,end+Vector2(2,-height),end+Vector2(0,8),7*alpha,Color(ICE,alpha))
				impact(n,end,Vector2.UP,age,ICE,20)
			else:
				for i in 3:
					var arm := Vector2.from_angle(i*PI/3+0.2)*(5+6*alpha)
					n.draw_line(end-arm,end+arm,Color(Color.WHITE,alpha),2,true)
				n.draw_arc(end,6+8*age,0,TAU,20,Color(WIND,alpha),1.5,true)
		g.Ally.OWL:
			var arrival := travel_fraction(true,power)
			var head := origin.lerp(end,minf(1,age/arrival))
			var bend := axis.orthogonal()*minf(11,origin.distance_to(head)*0.18)
			var bolt := PackedVector2Array([origin,origin.lerp(head,0.38)+bend,origin.lerp(head,0.57)-bend,head])
			var hue := Color("#ffc257") if power else WIND
			var weight := 9.0 if power and event.hop==0 else 4.5
			n.draw_polyline(bolt,Color(hue.darkened(0.45),alpha),weight*alpha+2,true)
			n.draw_polyline(bolt,Color(hue,alpha),weight*alpha,true)
			n.draw_polyline(bolt,Color(Color.WHITE,alpha),1.4,true)
			if age >= arrival:
				if power and event.hop == 0 and age < 0.80:
					var column := PackedVector2Array([end+Vector2(6,-48),end+Vector2(-5,-25),end+Vector2(4,-28),end])
					n.draw_polyline(column,Color(hue,alpha),7*alpha+1,true)
					n.draw_polyline(column,Color(Color.WHITE,alpha),2,true)
				impact(n,end,axis,(age-arrival)/(1-arrival),hue,26 if power and event.hop==0 else 12)
		g.Ally.HEDGEHOG:
			var travel := minf(1,age/travel_fraction(false,power))
			var head := origin.lerp(end,travel)
			var length := minf(origin.distance_to(head),32 if power else 15)
			var hue := EMBER if power else WIND
			n.draw_line(origin,head,Color(hue,alpha*0.55),2.5 if power else 1.5,true)
			shard(n,head,head-axis*length,5*alpha if power else 3*alpha,Color(hue,alpha))
			if travel >= 1:
				if power:
					n.draw_set_transform(end,axis.angle(),Vector2(0.45,1))
					n.draw_arc(Vector2.ZERO,7+age*17,0,TAU,32,Color(hue,alpha),2.5,true)
					n.draw_set_transform(Vector2.ZERO)
				impact(n,end,axis,age,hue,30 if power else 13)
