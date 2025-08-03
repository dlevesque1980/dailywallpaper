import 'package:dailywallpaper/models/image_item.dart';
import 'package:dailywallpaper/widget/text_with_hyperlink.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;

class InfoImage extends StatelessWidget {
  final ImageItem image;

  InfoImage({required this.image});

  final double descFontSize = 20.0;
  final double cpRightFontSize = 15.0;

  @override
  Widget build(BuildContext context) {
    return new IconButton(
        icon: Icon(Icons.info, color: Colors.white),
        padding: EdgeInsets.all(0.0),
        onPressed: () => {
              showModalBottomSheet<void>(
                  context: context,
                  builder: (BuildContext context) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          padding: EdgeInsets.only(top: 16.0, bottom: 16.0, left: 12.0, right: 12.0),
                          child: SingleChildScrollView(
                            child: Column(
                              children: <Widget>[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    image.description ?? "",
                                    style: material.TextStyle(fontSize: 20.0, color: Colors.black, package: "dailywallpaper"),
                                  ),
                                ),
                                Text(""),
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextWithHyperLink(text: image.copyright, color: Colors.black, hyperlinkColor: Colors.indigoAccent)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  })
            });
  }
}
