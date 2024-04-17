PNAMES = ["I", "O", "J", "L", "S", "T", "Z"]

class PieceData:
	def __init__(self, squares, color_index, next_piece):
		self.squares     = squares
		self.color_index = color_index
		self.next_piece  = next_piece
	
	def encode_xy(self) -> list[int]:
		coords = []
		for (x, y) in self.squares:
			e = y << 2 | x
			coords.append(e)
		return coords
	
	def encode_coords(self) -> int:
		coords = self.encode_xy()
		value = 0
		for coord in coords:
			value = (value << 4) | coord
		return value
	
	def encode(self):
		coords = self.encode_coords()
		nexttr = self.next_piece
		colori = self.color_index
		return colori << 24 | nexttr << 16 | coords
	
	def encode_hex(self):
		val32 = self.encode()
		return f"{val32:#0{8 + 2}x}"
	
	def __str__(self) -> str:
		coords = ", ".join([f"(x: {x}, y: {y})" for (x, y) in self.squares])
		return f"type = {PNAMES[self.color_index - 1]}, color_index = {self.color_index}, next_index = {self.next_piece}, squares = [{coords}]"


infos = []

# I (2)
infos.append(PieceData([(0, 2), (1, 2), (2, 2), (3, 2)], 1, 1)) # 0
infos.append(PieceData([(2, 0), (2, 1), (2, 2), (2, 3)], 1, 0)) # 1

# O (1)
infos.append(PieceData([(1, 1), (2, 1), (1, 2), (2, 2)], 2, 2)) # 2

# J (4)
infos.append(PieceData([(0, 1), (1, 1), (2, 1), (2, 2)], 3, 4)) # 3
infos.append(PieceData([(1, 0), (1, 1), (0, 2), (1, 2)], 3, 5)) # 4
infos.append(PieceData([(0, 0), (0, 1), (1, 1), (2, 1)], 3, 6)) # 5
infos.append(PieceData([(1, 0), (2, 0), (1, 1), (1, 2)], 3, 3)) # 6

# L (4)
infos.append(PieceData([(0, 1), (1, 1), (2, 1), (0, 2)], 4, 8)) # 7
infos.append(PieceData([(0, 0), (1, 0), (1, 1), (1, 2)], 4, 9)) # 8
infos.append(PieceData([(2, 0), (0, 1), (1, 1), (2, 1)], 4, 10)) # 9
infos.append(PieceData([(1, 0), (1, 1), (1, 2), (2, 2)], 4, 7)) # 10

# S (2)
infos.append(PieceData([(1, 1), (2, 1), (0, 2), (1, 2)], 5, 12)) # 11
infos.append(PieceData([(1, 0), (1, 1), (2, 1), (2, 2)], 5, 11)) # 12

# T (4)
infos.append(PieceData([(0, 1), (1, 1), (2, 1), (1, 2)], 6, 14)) # 13
infos.append(PieceData([(1, 0), (0, 1), (1, 1), (1, 2)], 6, 15)) # 14
infos.append(PieceData([(1, 0), (0, 1), (1, 1), (2, 1)], 6, 16)) # 15
infos.append(PieceData([(1, 0), (1, 1), (2, 1), (1, 2)], 6, 13)) # 16

# Z (2)
infos.append(PieceData([(0, 1), (1, 1), (1, 2), (2, 2)], 7, 18)) # 17
infos.append(PieceData([(2, 0), (1, 1), (2, 1), (1, 2)], 7, 17)) # 18

print("Infos: ")
for (i, info) in enumerate(infos):
	print(f"[{i}] {info}")

print("\nEncoded Values: ")
for info in infos:
	print(info.encode_hex())