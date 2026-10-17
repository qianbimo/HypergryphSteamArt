# Deterministic composition for every future official background update.
if (-not ('ArknightsCoverComposer' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
public static class ArknightsCoverComposer {
    public static void Create(string backgroundPath, string logoPath, string outputPath) {
        const int width = 600, height = 900;
        using (var background = Image.FromFile(backgroundPath))
        using (var logo = new Bitmap(logoPath))
        using (var canvas = new Bitmap(width, height))
        using (var g = Graphics.FromImage(canvas)) {
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.CompositingQuality = CompositingQuality.HighQuality;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            double scale = Math.Max((double)width/background.Width, (double)height/background.Height);
            float w = (float)(background.Width*scale), h = (float)(background.Height*scale);
            g.DrawImage(background, new RectangleF((width-w)/2, (height-h)/2, w, h));
            int left=logo.Width, top=logo.Height, right=-1, bottom=-1;
            double luminance=0, alphaWeight=0;
            for(int y=0; y<logo.Height; y++) for(int x=0; x<logo.Width; x++) {
                var pixel=logo.GetPixel(x,y);
                if(pixel.A <= 8) continue;
                luminance+=(0.2126*pixel.R+0.7152*pixel.G+0.0722*pixel.B)*pixel.A;
                alphaWeight+=pixel.A;
                left=Math.Min(left,x); top=Math.Min(top,y);
                right=Math.Max(right,x); bottom=Math.Max(bottom,y);
            }
            if(right<left) throw new InvalidOperationException("Logo has no visible pixels.");
            // Choose the lower gradient to contrast with the original game logo.
            int shadeColor=luminance/alphaWeight < 128 ? 255 : 0;
            using (var shade = new LinearGradientBrush(new Point(0, 540), new Point(0, height),
                Color.FromArgb(0,shadeColor,shadeColor,shadeColor), Color.FromArgb(220,shadeColor,shadeColor,shadeColor))) {
                g.FillRectangle(shade, 0, 540, width, height-540);
            }
            var source = new Rectangle(left,top,right-left+1,bottom-top+1);
            double logoScale=Math.Min(460.0/source.Width, 220.0/source.Height);
            float logoWidth=(float)(source.Width*logoScale), logoHeight=(float)(source.Height*logoScale);
            g.DrawImage(logo,new RectangleF((width-logoWidth)/2,height-42-logoHeight,logoWidth,logoHeight),source,GraphicsUnit.Pixel);
            var codec = Array.Find(ImageCodecInfo.GetImageEncoders(), c => c.MimeType=="image/jpeg");
            using(var parameters = new EncoderParameters(1)) {
                parameters.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 92L);
                canvas.Save(outputPath,codec,parameters);
            }
        }
    }
}
'@
}
