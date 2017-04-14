.PHONY: all

all: release

release:
	hugo
	s3cmd sync --delete-removed -P public/ s3://blog.joshuamorgan.com.au/

clean:
	$(RM) -r public
