import sys, importlib.util
spec=importlib.util.spec_from_loader("hb", loader=None)
src=open("tools/han-book").read()
m={}
exec(compile(src.replace('if __name__ == "__main__":','if False:'),"hb","exec"),m)
print("\n".join(m["load"](sys.argv[1])))
