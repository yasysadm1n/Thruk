// https://www.sencha.com/forum/showthread.php?159879-KPI-Gauge
Ext.define('Ext.ux.chart.series.KPIGauge', {
    extend: 'Ext.chart.series.Gauge',
    alias: 'series.kpigauge',
    type: 'kpigauge',
    drawSeries: function () {
        var me = this,
            chart = me.chart,
            store = chart.getChartStore(),
            group = me.group,
            animate = me.chart.animate,
            axis = me.chart.axes.get(0),
            minimum = axis && axis.minimum || me.minimum || 0,
            maximum = axis && axis.maximum || me.maximum || 0,
            ranges = me.ranges,
            field = me.angleField || me.field || me.xField,
            surface = chart.surface,
            chartBBox = chart.chartBBox,
            rad = me.rad,
            donut = +me.donut,
            values = {},
            items = [],
            seriesStyle = me.seriesStyle,
            seriesLabelStyle = me.seriesLabelStyle,
            cos = Math.cos,
            sin = Math.sin,
            rendererAttributes, centerX, centerY, slice, slices, sprite, value,
            item, ln, record, i, j, r, slice, splitAngle, rl, startAngle, endAngle, middleAngle, sliceLength, path,
            p, spriteOptions, bbox, valueAngle, pivotRadius, tempValue = 0;


        Ext.apply(seriesStyle, me.style || {});


        me.setBBox();
        bbox = me.bbox;


        //if not store or store is empty then there's nothing to draw
        if (!store || !store.getCount() || me.seriesIsHidden) {
            me.hide();
            me.items = [];
            return;
        }

        centerX = me.centerX = chartBBox.x + (chartBBox.width / 2);
        centerY = me.centerY = chartBBox.y + chartBBox.height;
        me.radius = Math.min(centerX - chartBBox.x, centerY - chartBBox.y);
        me.slices = slices = [];
        me.items = items = [];

        if (!me.value) {
            record = store.getAt(0);
            me.value = record.get(field);
        }

        value = me.value;
        // added by Irfan Maulana for temporary value
        tempValue = value;
        // added by Irfan maulana for set to maximum value when value > maximum value
        if(value > maximum){
            value = maximum;
        }

        for (r = 0, rl = ranges.length; r < rl; r++) {
            splitFromAngle = -180 * (1 - (ranges[r].from - minimum) / (maximum - minimum));
            splitToAngle = -180 * (1 - (ranges[r].to - minimum) / (maximum - minimum));
            // sni: make threshold visible if its only a line
            if(splitToAngle == splitFromAngle) { splitToAngle = splitToAngle- 2;}
            slices.push ({
                startAngle: splitFromAngle,
                endAngle: splitToAngle,
                rho: me.radius,
                color: ranges[r].color
            });
        }

        //do pie slices after.
        for (i = 0, ln = slices.length; i < ln; i++) {
            slice = slices[i];
            sprite = group.getAt(i);
            //set pie slice properties
            rendererAttributes = Ext.apply({
                segment: {
                    startAngle: slice.startAngle,
                    endAngle: slice.endAngle,
                    margin: 0,
                    rho: slice.rho,
                    startRho: slice.rho * +donut / 100,
                    endRho: slice.rho
                }
            }, Ext.apply(seriesStyle, { fill: slice.color}));


            item = Ext.apply({},
            rendererAttributes.segment, {
                slice: slice,
                series: me,
                storeItem: record,
                index: i
            });
            items[i] = item;
            // Create a new sprite if needed (no height)
            if (!sprite) {
                spriteOptions = Ext.apply({
                    type: "path",
                    group: group
                }, Ext.apply(seriesStyle, { fill: slice.color }));
                sprite = surface.add(Ext.apply(spriteOptions, rendererAttributes));
                if(me.needleSprite) { me.needleSprite.destroy(); delete me.needleSprite; }
            }
            slice.sprite = slice.sprite || [];
            item.sprite = sprite;
            slice.sprite.push(sprite);
            if (animate) {
                rendererAttributes = me.renderer(sprite, record, rendererAttributes, i, store);
                sprite._to = rendererAttributes;
                me.onAnimate(sprite, {
                    to: rendererAttributes
                });
            } else {
                rendererAttributes = me.renderer(sprite, record, Ext.apply(rendererAttributes, {
                    hidden: false
                }), i, store);
                sprite.setAttributes(rendererAttributes, true);
            }
        }


        if (me.needle) {
            valueAngle = (-180 * (1 - (value - minimum) / (maximum - minimum))) * Math.PI / 180;
            pivotRadius = me.needle.pivotRadius || 7;
            if (!me.needleSprite) {
                me.needlePivotSprite = me.chart.surface.add({
                    type: 'circle',
                    fill: me.needle.pivotFill || '#222',
                    radius: pivotRadius,
                    x: centerX,
                    y: centerY
                });
                me.needleSprite = me.chart.surface.add({
                    type: 'path',
                    path: [
                        'M', centerX + (me.radius * 0 / 100) * cos(valueAngle),
                            centerY + -Math.abs((me.radius * 0 / 100) * sin(valueAngle)),
                        'L', centerX + me.radius * cos(valueAngle),
                            centerY + -Math.abs(me.radius * sin(valueAngle))
                    ],
                    'stroke-width': me.needle.width || 2,
                    'stroke': me.needle.pivotFill || '#222'
                });
                /*
                me.valueSprite = me.chart.surface.add({
                    type: 'text',
                    //text: value, remark by Irfan Maulana -> change to temp value to give actual value of store
                    text: tempValue,
                    fill: me.needle.pivotFill || '#222',
                    font: '14px Arial',
                    x: centerX - (pivotRadius),
                    y: centerY - (me.radius / 2)
                });
                */
            } else {
                if (animate) {
                    me.onAnimate(me.needlePivotSprite, {
                        to: {
                            x: centerX,
                            y: centerY
                        }
                    });
                    me.onAnimate(me.needleSprite, {
                        to: {
                            path: [
                                'M', centerX + (me.radius * 0 / 100) * cos(valueAngle),
                                    centerY + -Math.abs((me.radius * 0 / 100) * sin(valueAngle)),
                               'L', centerX + me.radius * cos(valueAngle),
                                    centerY + -Math.abs(me.radius * sin(valueAngle))
                            ]
                        }
                    });
                } else {
                    me.needlePivotSprite.setAttributes({
                        type: 'circle',
                        fill: me.needle.pivotFill || '#222',
                        radius: me.needle.pivotRadius || 7,
                        x: centerX,
                        y: centerY
                    });
                    me.needleSprite.setAttributes({
                        type: 'path',
                        path: ['M', centerX + (me.radius * 0 / 100) * cos(valueAngle),
                                    centerY + -Math.abs((me.radius * 0 / 100) * sin(valueAngle)),
                               'L', centerX + me.radius * cos(valueAngle),
                                    centerY + -Math.abs(me.radius * sin(valueAngle))]
                    });
                }
                /*
                // Nothing to animate so we use a single call to update the Value Sprite's attributes no matter "animate" config
                me.valueSprite.setAttributes({
                    type: 'text',
                    //text: value, remark by Irfan Maulana -> change to temp value to give actual value of store
                    text: tempValue,
                    x: centerX - (pivotRadius),
                    y: centerY - (me.radius / 2)
                });
                */
            }
            me.needlePivotSprite.setAttributes({
                hidden: false
            }, true);
            me.needleSprite.setAttributes({
                hidden: false
            }, true);
            /*
            me.valueSprite.setAttributes({
                hidden: false
            }, true);
            */
        }
        delete me.value;
    }
});
